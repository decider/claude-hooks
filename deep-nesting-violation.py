def test_deep_nesting():
    if True:
        if True:
            if True:
                if True:
                    if True:
                        if True:
                            if True:
                                if True:
                                    print("This is way too deeply nested and should trigger pre-tool hook")