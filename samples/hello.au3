; Realistic AutoIt v3 sample — exercises the Phase 2 grammar surface.
; Build, rank, and report a small scoreboard via a COM dictionary.

#include-once
#include <MsgBoxConstants.au3>
#include "helpers.au3"

#region constants
Global Const $MAX_SCORE = 100
Global Const $HEX_MASK  = 0xFF
Global Const $LABELS    = ["bronze", "silver", "gold"]
Global Const $WEIGHTS   = [1.0, 1.5, 2.0]

; Enum declared at module scope with `Global` modifier (Phase 2j).
; These constants index into $LABELS so RankScore can name them.
Global Enum $RANK_BRONZE, $RANK_SILVER, $RANK_GOLD
#endregion constants

#cs Author notes:
    Long-form block comment using #cs / #ce. Both delimiters can carry
    trailing text on the same line (Phase 2j) — common convention is to
    label the closer to match the opener.
    Strings can be single- or double-quoted: 'don''t' vs "say ""hi""".
#ce ----------------------------------------------------------------

; Hot-key handler — Esc exits cleanly. Static keeps a press count
; across invocations.
HotKeySet("{ESC}", "Quit")

Func Quit()
    Static $iCount = 0
    $iCount += 1
    ConsoleWrite("Esc pressed " & $iCount & " time(s)" & @CRLF)
    Exit 0
EndFunc

; Build a dictionary of player → score using Mod() to clamp.
Func BuildScoreboard(ByRef $oDict, Const $iCount = 5)
    For $i = 1 To $iCount
        Local $sName  = "player_" & $i
        Local $iScore = Mod($i * 17, $MAX_SCORE)
        $oDict.Add($sName, $iScore)
    Next
EndFunc

; Build a 2D bonus grid: each row is [player-name, bonus-points].
; Exercises array literals (size-inferred and explicit), multi-dim
; declarations with expression-valued sizes, and indexing into both.
; Phase 2j adds two more features here: `.5` leading-dot number and
; a `ReDim` to grow the grid for a trailing summary row.
Func BuildBonusGrid()
    Local $names[] = ["Alice", "Bob", "Carol", "Dan"]
    Local $grid[UBound($names)][2]
    For $i = 0 To UBound($names) - 1
        $grid[$i][0] = $names[$i]
        ; `.5` is the leading-dot float form (no integer part required).
        $grid[$i][1] = ($i + 1) * 10 * $WEIGHTS[Mod($i, 3)] + .5
    Next
    ; ReDim grows the array by one row to hold a summary entry.
    ReDim $grid[UBound($grid) + 1][2]
    $grid[UBound($grid) - 1][0] = "TOTAL"
    $grid[UBound($grid) - 1][1] = 0
    Return $grid
EndFunc

; Local-scope demo: a nested 2D literal, indexing a stored array, and
; 1D array dims with numeric sizes. Pure illustration — never called at
; runtime, just there for Zed to highlight.
Func ArrayShapesDemo()
    Local $matrix     = [[1, 2, 3], [4, 5, 6]]
    Local $firstRow   = $matrix[0]
    Local $buffer[16]
    Local $a[3], $b[4], $c
    Return $matrix[1][2] + $firstRow[1] + $buffer[0] + $a[0] + $b[0] + $c
EndFunc

; Bucket a numeric score into a label using Switch with ranges.
; Indexes $LABELS via the `Global Enum` constants declared above —
; reads more clearly than $LABELS[0..2].
Func RankScore($iScore)
    Switch $iScore
        Case 0 To 33
            Return $LABELS[$RANK_BRONZE]
        Case 34 To 66
            Return $LABELS[$RANK_SILVER]
        Case 67 To $MAX_SCORE
            Return $LABELS[$RANK_GOLD]
        Case Else
            Return 'unknown'
    EndSwitch
EndFunc

; Single-line If used to early-return.
Func RequireNonEmpty($oDict)
    If $oDict.Count = 0 Then Return SetError(1, 0, False)
    Return True
EndFunc

; Spin briefly using Do/Until with a float literal and line continuation.
Func WaitABit()
    Local $fStart = TimerInit()
    Do
        Sleep(50)
    Until TimerDiff($fStart) > _
          3.14 * 1000
EndFunc

; UDF name begins with the `Do` keyword — exercises that identifiers
; like `DoFinalize`, `EnumKeys`, `ForEach` aren't mis-tokenized as
; `<keyword> + <identifier>` (Phase 2j).
Func DoFinalize($iCount)
    ConsoleWrite("Finalized " & $iCount & " entries." & @CRLF)
EndFunc

Func Main()
    Local $oDict = ObjCreate("Scripting.Dictionary")
    BuildScoreboard($oDict)

    If Not RequireNonEmpty($oDict) Then
        MsgBox($MB_ICONERROR, "Scoreboard", "Empty dictionary.")
        Return
    EndIf

    Local $sReport = "Scoreboard:" & @CRLF
    For $vKey In $oDict.Keys
        $sReport &= StringFormat("  %-12s %s%s", _
                                 $vKey, _
                                 RankScore($oDict.Item($vKey)), _
                                 @CRLF)
    Next

    ConsoleWrite($sReport)
    MsgBox($MB_OK, "AutoIt sample", $sReport)

    ; Array demo: build a 2D grid and read from it with chained indexing.
    ; The ternary `?:` (Phase 2j) labels the magnitude inline.
    Local $bonuses = BuildBonusGrid()
    ConsoleWrite("Top bonus: " & $bonuses[0][0] & " -> " & _
                 ($bonuses[0][1] > 50 ? "HIGH" : "low") & @CRLF)

    WaitABit()
    DoFinalize(UBound($bonuses))
EndFunc

Main()
