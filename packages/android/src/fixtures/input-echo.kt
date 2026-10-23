fun main() {
    val input = CraftNativeInputEcho()
    check(!input.accept("", ""))
    input.record("a")
    input.record("ab")
    check(!input.accept("a", "ab"))
    // Another node's mutation renders the same old prop after its echo was
    // consumed. It must not erase the newer keystroke or move its caret.
    check(!input.accept("a", "ab"))
    check(!input.accept("ab", "ab"))
    check(input.accept("", "ab")) // An intentional clear still applies.
    input.record("c")
    input.record("co")
    input.record("coach")
    check(!input.accept("co", "coach")) // Coalesced echoes.
    check(!input.accept("co", "coach"))
    check(!input.accept("coach", "coach"))
    check(input.accept("Coach", "coach")) // Deliberate formatting.
    check(!input.accept(null, "Coach")) // Uncontrolled, then controlled.
    check(input.accept("New Exercise", "Coach"))
    val retyped = CraftNativeInputEcho()
    check(!retyped.accept("a", "a"))
    retyped.record("")
    retyped.record("a")
    // An unchanged prop is not an acknowledgement of a later edit that
    // happens to have the same text (delete, then immediately retype).
    check(!retyped.accept("a", "a"))
    check(!retyped.accept("", "a"))
    check(!retyped.accept("a", "a"))
    val counted = CraftNativeInputEcho()
    check(!counted.accept("", "", 0))
    check(counted.record("Pl") == 1)
    check(counted.record("Pla") == 2)
    check(!counted.accept("Pl", "Pla", 1))
    check(counted.record("Plan") == 3)
    check(!counted.accept("Pla", "Plan", 2))
    check(counted.record("Plane") == 4)
    check(!counted.accept("Plane", "Plane", 4))
    check(!counted.accept("Plan", "Plane", 3)) // Late even after latest ack.
    check(counted.accept("", "Plane", 4)) // Current intentional clear.
    check(counted.accept("Plan", "", 4)) // External value may equal old typing.
    println("Android native input echoes: passed")
}
