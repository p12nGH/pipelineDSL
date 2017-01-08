-- | Verilog code generation
module Hardware.PipelineDSL.Verilog (
    toVerilog,
    toVerilogHW
) where

import Data.List (intercalate)
import Data.Maybe (fromMaybe)

import Hardware.PipelineDSL.Pipeline

mOpsSign Or = " | "
mOpsSign And = " & "
mOpsSign Sum = " + "
mOpsSign Mul = " * "

bOpsSign Sub = " - "
bOpsSign (Cmp Equal) = " == "
bOpsSign (Cmp NotEqual) = "!="
bOpsSign (Cmp LessOrEqual) = "<="
bOpsSign (Cmp GreaterOrEqual) = ">="
bOpsSign (Cmp Less) = "<"
bOpsSign (Cmp Greater) = ">"

uOpsSign Not = "~"
uOpsSign Neg = "-"

vcode :: Signal -> String
vcode = vcode' . simplify . simplify . simplify . simplify  where
    vcode' (SigRef n Nothing _) = "sig_" ++ (show n)
    vcode' (SigRef _ (Just n) _) = n
    vcode' (MultyOp o ops) = "(" ++ intercalate (mOpsSign o) (map vcode' ops) ++ ")"
    vcode' (BinaryOp o op1 op2) = "(" ++ (vcode' op1) ++ (bOpsSign o) ++ (vcode' op2) ++ ")"

    vcode' (UnaryOp o op@(Alias _ _)) = (uOpsSign o)  ++ (vcode' op)
    vcode' (UnaryOp o op@(SigRef _ _ _)) = (uOpsSign o)  ++ (vcode' op)
    vcode' (UnaryOp o op@(RegRef _ _)) = (uOpsSign o)  ++ (vcode' op)
    vcode' (UnaryOp o op) = (uOpsSign o) ++ "(" ++ (vcode' op) ++ ")"

    vcode' (Lit val width) = (show width) ++ "'d" ++ (show val)
    vcode' (Alias n _) = n
    vcode' Undef = "'x"
    vcode' (RegRef n (Reg _ _ Nothing)) = "reg_" ++ (show n)
    vcode' (RegRef n (Reg _ _ (Just name))) = name ++ (show n)
    vcode' (Stage (LogicStage _ _ r)) = vcode' r
    vcode' (PipelineStage p) = vcode' $ head $ pipeStageLogicStages p
    vcode' (IPipePortNB p) = vcode' $ portData p

print_width 1 = ""
print_width n = "[" ++ (show $ n - 1) ++ ":0] "

printSigs s = unlines (map printStg stgs) where
    printStg (i, x, name) = intercalate "\n" [decl] where
        width = getSignalWidth (Just i) x
        sig = case name of
            Nothing -> "sig_" ++ (show i)
            Just n -> n ++ "_" ++ (show i)
        decl' = "\n\nlogic " ++ (print_width width) ++ sig ++ ";\n" 
        assign = "assign " ++ sig ++ " = " ++ vcode x ++ ";"
        decl = decl' ++ assign
    stgs = smSignals s

toVerilog m = toVerilog' s where
    (_, s, _) = rPipe m

toVerilogHW m = toVerilog' s where
    (_, s) = rHW m

toVerilog' s = (printSigs s) ++ (unlines $ map printStg stgs)  where
    printStg (i, x@(Reg c reset_value mname)) = intercalate "\n" [decl] where
        width = maximum $ map ((getSignalWidth (Just i)). snd) c

        name = fromMaybe "reg_" mname
        reg = name ++ (show i)
        cond (e, v) =
            "if (" ++ (vcode e) ++ ")\n" ++
            "            " ++ reg ++ " <= " ++ (vcode v) ++ ";"
        condassigns = intercalate "\n        else " $ map cond c

        decl = "\nlogic " ++ (print_width width) ++ reg ++ ";\n" ++
            "always @(posedge clk or negedge rst_n) begin\n" ++
            "    if (rst_n == 0) begin\n" ++
            "        " ++ reg ++ " <= " ++ (vcode reset_value) ++ ";\n" ++
            "    end else begin\n        " ++ condassigns ++
            "\n    end" ++  "\nend"
    stgs = smRegs s
