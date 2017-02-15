import Hardware.PipelineDSL

(.==) = BinaryOp (Cmp Equal)

main = putStrLn $ toVerilog $ do
    let s1 = (Alias "sig" 2)
    r <- mkReg []
    fsm $ do
        wait $ s1 .== 1
        r .= 7
        wait $ s1 .== 2
        r .= r + 1
        wait $ s1 .== 3