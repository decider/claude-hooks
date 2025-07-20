def test_bad_indentation():
   print("This has 3 spaces instead of 4")
     print("This has 5 spaces instead of 4")
       print("This has 7 spaces instead of 4")
         print("This violates PEP8 indentation rules")