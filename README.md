# VScript-Coroutines
Just a simple VScript snippet where you can control code with yields.

## Usage:
Simply include the script somewhere once, like the main manager script for example.
- `IncludeScript("coroutines.nut", this)`
Or you can have a **logic_script** contain this script, but preferably include it.

### To use in code:
An example usage:
```
IncludeScript("coroutines.nut", this)

NewThread(function() {
  printl("Hello, World!")
  yield 2.0 // This will delay the script by 2.0 seconds.
  printl("Hello, World once again!")
})
```

Usages for running in a loop:
```
NewThread(function() {
  local falling = true
  while (falling) {
    falling = TraceLine(self.GetOrigin(), self.GetOrigin() - Vector(0, 0, 10), self) > 0.99
    if (!falling) {
      printl("Landed!")
      break
    }
    yield FrameTime()
  }
})
```

Usages to cancel a thread from running:
```
local warmup = NewThread(function(){
  printl("Warmup ends in 20s")
  yield 10.0
  printl("Warmup ends in 10s")
  yield 10.0
  printl("Warmup ends!")
})

CancelThread(warmup) // Only "Warmup ends in 20s" gets printed 

local warmup2 = NewThread(function(){
  printl("Warmup ends in 20s")
  if (end_early)
    yield "kill" // This will end the thread early.
  else
    yield 10.0
  printl("Warmup ends in 10s")
  yield 10.0
  printl("Warmup ends!")
})
```
