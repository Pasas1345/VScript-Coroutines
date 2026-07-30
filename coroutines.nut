// -------------------------------
// Coroutine VScript by Pasas1345
// -------------------------------
// Fine print here: 
// thanks to ficool2 for the mentioning of generator functions to make this actually possible
// (and actually not crash the server with newthread())
//
// AI was used to actually help out the structure of this.
// Structuring of this entire ordeal is entirely up to me

// ---------------------------------------------------------------------------------
// Usage and functions:
// - NewThread(func, ...): 	The actual meat of this script.
//							Call it and then use yield <delay> to delay execution.
//							Returns the function where you can cancel it.
//							You can also do yield "kill"/"stop" to cancel it.
//
// - CancelThread(co):		Pass in a thread to cancel execution.
//
// - CountActiveThreads():	Just a debug command showing all info about coroutines.
//
// ---------------------------------------------------------------------------------

if (!("Coroutine" in getroottable())) ::Coroutine <- {}
::Coroutine.coroutine_delays <- {}
if (!("coroutine_entity" in Coroutine)) Coroutine.coroutine_entity <- null

// ------------------------------------------------------------
// Creates the thread. Optionally pass in extra arguments if needed. 
// Anything else can be passed through the argument table.
// (use vargv[] inside the thread.)
// ------------------------------------------------------------
// Internally called threads in this file, this allows delays inside without stopping any other scripts.
// Example usage could be delayed execution of code, like having a map print something, and 3 seconds later
// something explodes.
// Usage:
// yield <delay> (ex. yield 5.0 (stops for 5 seconds.))
// ------------------------------------------------------------
::NewThread <- function(func, ...) {
	local co = null

	if (typeof(func) == "generator") {
		co = func
	}
	else if (typeof(func) == "function") {
		if (vargv.len() <= 0) {
			co = func()
		}
		else
			co = func(vargv)
	}

	::Coroutine.coroutine_delays[co] <- {
		active = true,
		suspended = false,
		suspend_time = 0,
		cancelled = false
		error = false
	}

	local ret = resume co

	if (co.getstatus() == "suspended") {
		if (ret == "kill" || ret == "stop") {
			::Coroutine.coroutine_delays[co].cancelled = true
		}
		else if (ret != null && (typeof(ret) == "integer" || typeof(ret) == "float")) {
			::Coroutine.coroutine_delays[co].suspended = true
			::Coroutine.coroutine_delays[co].suspend_time = Time() + ret.tofloat()
		}
	}
	
	return co
}

// Another way of calling it, though because it is generator functions, thats why i have it here.
::Generator <- ::NewThread

// Use this to cancel a thread and stop its execution.
::CancelThread <- function(thread) {
	if (thread in ::Coroutine.coroutine_delays) {
		printf("[Coroutines] Cancelling thread.\n")
		
		// Mark as inactive to skip processing in CoroutineTick
		::Coroutine.coroutine_delays[thread].active = false

		::Coroutine.coroutine_delays[thread].cancelled = true
		
		// Schedule it for cleanup on next tick
		return true
	}
	
	return false
}

// Debugging
::CountActiveThreads <- function() {
	local count = 0
	local suspended_count = 0
	local running_count = 0
	local error_count = 0
	
	foreach(co, data in ::Coroutine.coroutine_delays) {
		if (data.active) {
			count++
			
			if (data.suspended)
				suspended_count++
			else if (co.getstatus() == "running")
				running_count++
		}

		if (data.error)
			error_count++
	}
	
	printl(format("[Coroutines] Active: %d (Suspended: %d, Running: %d, Errors: %d)", 
				count, suspended_count, running_count, error_count))
	
	return {
		total = count
		suspended = suspended_count
		running = running_count
		errors = error_count
	}
}

// -----------------------------------------------------------
// Create a new entity for the threads to take place in, once.
// -----------------------------------------------------------
if (::Coroutine.coroutine_entity == null) {
	::Coroutine.coroutine_entity = SpawnEntityFromTable("info_target", {
		origin = Vector(0, 0, 0)
	})
	NetProps.SetPropBool(::Coroutine.coroutine_entity, "m_bForcePurgeFixedupStrings", true)


	::Coroutine.coroutine_entity.ValidateScriptScope()
	::Coroutine.coroutine_entity.GetScriptScope().Tick <- function() {
		local current_time = Time()
		local threads_to_clean = []

		foreach(co, data in ::Coroutine.coroutine_delays) {
			if (co == null || typeof(co) != "generator") {
				threads_to_clean.push(co)
				continue
			}

			if (data.cancelled) {
				threads_to_clean.push(co)
				continue
			}

			if (!data.active)
				continue

			local resume_needed = false
			
			if (data.suspended) {
				if (data.suspend_time <= current_time) {
					data.suspended = false
					resume_needed = true
				}
			}
			else if (co.getstatus() == "suspended") {
				resume_needed = true
			}

			if (resume_needed) {
				if (co.getstatus() == "suspended") {
					local ret = resume co
					if (co.getstatus() == "suspended") {
						if (ret == "kill" || ret == "stop") {
							data.cancelled = true
						}
						else if (ret != null && (typeof(ret) == "integer" || typeof(ret) == "float")) {
							data.suspended = true
							data.suspend_time = current_time + ret.tofloat()
						}
					}
				}
			}

			if (co.getstatus() != "suspended" && co.getstatus() != "running")
				threads_to_clean.push(co)
		}

		foreach(co in threads_to_clean) {
			delete ::Coroutine.coroutine_delays[co]
		}

		return -1
	}

	AddThinkToEnt(Coroutine.coroutine_entity, "Tick")
	printl("[Coroutines] Created Coroutine Entity.")
}
