// Test file with violations to trigger stop hook blocking
function problematicFunction(a: any, b: any, c: any, d: any, e: any, f: any, g: any) {
    if (a) {
        if (b) {
            if (c) {
                if (d) {
                    if (e) {
                        if (f) {
                            if (g) {
                                // Way too nested and too many parameters
                                console.log("This line is intentionally way too long to exceed the 80 character limit that we have configured in our code quality rules and should trigger a violation");
                                console.log("Line 1"); console.log("Line 2"); console.log("Line 3");
                                console.log("Line 4"); console.log("Line 5"); console.log("Line 6");
                                console.log("Line 7"); console.log("Line 8"); console.log("Line 9");
                                console.log("Line 10"); console.log("Line 11"); console.log("Line 12");
                                console.log("Line 13"); console.log("Line 14"); console.log("Line 15");
                                console.log("Line 16"); console.log("Line 17"); console.log("Line 18");
                                console.log("Line 19"); console.log("Line 20"); console.log("Line 21");
                                console.log("Line 22"); console.log("Line 23"); console.log("Line 24");
                                console.log("Line 25"); console.log("Line 26"); console.log("Line 27");
                                return 42 + 1337 + 999 + 555; // Magic numbers everywhere
                            }
                        }
                    }
                }
            }
        }
    }
    return 0;
}