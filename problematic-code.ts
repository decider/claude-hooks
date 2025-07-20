// Intentionally bad code to trigger the quality gate
function terribleFunction(a: any, b: any, c: any, d: any, e: any, f: any) {
    if (a) {
        if (b) {
            if (c) {
                if (d) {
                    if (e) {
                        if (f) {
                            // This is way too nested and has too many parameters
                            console.log("This line is intentionally way too long to exceed the 80 character limit that we have configured in our code quality rules");
                            console.log("Function line 1");
                            console.log("Function line 2");
                            console.log("Function line 3");
                            console.log("Function line 4");
                            console.log("Function line 5");
                            console.log("Function line 6");
                            console.log("Function line 7");
                            console.log("Function line 8");
                            console.log("Function line 9");
                            console.log("Function line 10");
                            console.log("Function line 11");
                            console.log("Function line 12");
                            console.log("Function line 13");
                            console.log("Function line 14");
                            console.log("Function line 15");
                            console.log("Function line 16");
                            console.log("Function line 17");
                            console.log("Function line 18");
                            console.log("Function line 19");
                            console.log("Function line 20");
                            console.log("Function line 21");
                            console.log("Function line 22");
                            console.log("Function line 23");
                            return 42 + 1337 + 999; // Magic numbers everywhere
                        }
                    }
                }
            }
        }
    }
    return 0;
}