Attribute VB_Name = "modCommandCode"
' modCommandCode.bas
' ...

Option Explicit

' Winamp Constants
Private Const WA_PREVTRACK   As Long = 40044 ' ...
Private Const WA_NEXTTRACK   As Long = 40048 ' ...
Private Const WA_PLAY        As Long = 40045 ' ...
Private Const WA_PAUSE       As Long = 40046 ' ...
Private Const WA_STOP        As Long = 40047 ' ...
Private Const WA_FADEOUTSTOP As Long = 40147 ' ...

Public Flood    As String ' ...?
Public floodCap As Byte   ' ...?

' prepares commands for processing, and calls helper functions associated with
' processing
Public Function ProcessCommand(ByVal Username As String, ByVal Message As String, _
    Optional ByVal InBot As Boolean = False, Optional ByVal WhisperedIn As Boolean = False) As Boolean
    
    ' default error response for commands
    On Error GoTo ERROR_HANDLER
    
    ' stores the access response for use when commands are
    ' issued via console
    Dim ConsoleAccessResponse As udtGetAccessResponse

    Dim i            As Integer ' loop counter
    Dim tmpMsg       As String  ' stores local copy of message
    Dim cmdRet()     As String  ' stores output of commands
    Dim PublicOutput As Boolean ' stores result of public command
                                ' output check (used for displaying command
                                ' output when issuing via console)
    
    ' create single command data array element for safe bounds checking
    ReDim Preserve cmdRet(0)
    
    ' create console access response structure
    With ConsoleAccessResponse
        .Access = 1001
        .Flags = "A"
    End With

    ' store local copy of message
    tmpMsg = Message
    
    ' replace message variables
    tmpMsg = Replace(tmpMsg, "%me", IIf((InBot), CurrentUsername, Username), 1)
    
    If (InBot = False) Then
        ' check for commands using universal command identifier (?)
        If (StrComp(Left$(tmpMsg, Len("?trigger")), "?trigger", vbTextCompare) = 0) Then
            ' remove universal command identifier from message
            tmpMsg = Mid$(tmpMsg, 2)
        
        ' check for commands using command identifier
        ElseIf ((Len(tmpMsg) >= Len(BotVars.Trigger)) And _
                (Left$(tmpMsg, Len(BotVars.Trigger)) = BotVars.Trigger)) Then
            
            ' remove command identifier from message
            tmpMsg = Mid$(tmpMsg, Len(BotVars.Trigger) + 1)
        
            ' check for command identifier and name combination
            ' (e.g., .Eric[nK] say hello)
            If (Len(tmpMsg) >= (Len(CurrentUsername) + 1)) Then
                If (StrComp(Left$(tmpMsg, Len(CurrentUsername) + 1), _
                    CurrentUsername & Space(1), vbTextCompare) = 0) Then
                        
                    ' remove username (and space) from message
                    tmpMsg = Mid$(tmpMsg, Len(CurrentUsername) + 2)
                End If
            End If
        
        ' check for commands using either name and colon (and space),
        ' or name and comma (and space)
        ' (e.g., Eric[nK]: say hello; and, Eric[nK], say hello)
        ElseIf ((Len(tmpMsg) >= (Len(CurrentUsername) + 2)) And _
                ((StrComp(Left$(tmpMsg, Len(CurrentUsername) + 2), CurrentUsername & ": ", _
                  vbTextCompare) = 0) Or _
                 (StrComp(Left$(tmpMsg, Len(CurrentUsername) + 2), CurrentUsername & ", ", _
                  vbTextCompare) = 0))) Then
            
            ' remove username (and colon/comma) from message
            tmpMsg = Mid$(tmpMsg, Len(CurrentUsername) + 3)
        Else
            ' allow commands without any command identifier if
            ' commands are sent via whisper
            If (Not (WhisperedIn)) Then
                ' return negative result indicating that message does not contain
                ' a valid command identifier
                ProcessCommand = False
                
                ' exit function
                Exit Function
            End If
        End If
    Else
        ' remove slash (/) from in-console message
        tmpMsg = Mid$(tmpMsg, 2)
        
        ' check for second slash indicating
        ' public output
        If (Left$(tmpMsg, 1) = "/") Then
            ' enable public display of command
            PublicOutput = True
        
            ' remove second slash (/) from in-console
            ' message
            tmpMsg = Mid$(tmpMsg, 2)
        End If
    End If

    ' check for multiple commands
    If (InStr(1, tmpMsg, "; ", vbTextCompare) > 0) Then
        Dim X() As String  ' ...
    
        X = Split(tmpMsg, "; ")
        
        ' loop through commands
        For i = 0 To UBound(X)
            ' send command to main processor
            If (InBot = True) Then
                ProcessCommand = ExecuteCommand(Username, ConsoleAccessResponse, _
                    X(i), InBot, cmdRet())
            Else
                ProcessCommand = ExecuteCommand(Username, GetAccess(Username), X(i), _
                    InBot, cmdRet())
            End If
            
            If (ProcessCommand) Then
                ' display command response
                If (cmdRet(0) <> vbNullString) Then
                    Dim j As Integer ' ...
                
                    ' loop through command response
                    For j = 0 To UBound(cmdRet)
                        If ((InBot) And (Not (PublicOutput))) Then
                            ' display message on screen
                            Call AddChat(RTBColors.ConsoleText, cmdRet(j))
                        Else
                            ' send message to battle.net
                            If (WhisperedIn) Then
                                ' whisper message
                                Call AddQ("/w " & IIf((Dii), "*", vbNullString) & _
                                    Username & Space(1) & cmdRet(j), 1)
                            Else
                                Call AddQ(cmdRet(j), 1)
                            End If
                        End If
                    Next j
                End If
            End If
        Next i
    Else
        ' send command to main processor
        If (InBot = True) Then
            ProcessCommand = ExecuteCommand(Username, ConsoleAccessResponse, tmpMsg, _
                InBot, cmdRet())
        Else
            ProcessCommand = ExecuteCommand(Username, GetAccess(Username), tmpMsg, _
                InBot, cmdRet())
        End If
        
        If (ProcessCommand) Then
            ' display command response
            If (cmdRet(0) <> vbNullString) Then
                ' loop through command response
                For i = 0 To UBound(cmdRet)
                    If ((InBot) And (Not (PublicOutput))) Then
                        ' display message on screen
                        Call AddChat(RTBColors.ConsoleText, cmdRet(i))
                    Else
                        ' display message
                        If ((WhisperedIn) Or _
                           ((BotVars.WhisperCmds) And (Not (InBot)))) Then
                           
                            ' whisper message
                            Call AddQ("/w " & IIf((Dii), "*", vbNullString) & _
                                Username & Space(1) & cmdRet(i), 1)
                        Else
                            Call AddQ(cmdRet(i), 1)
                        End If
                    End If
                Next i
            End If
        End If
    End If
    
    ' break out of function before reaching error
    ' handler
    Exit Function
    
' default (if all else fails) error handler to keep erroneous
' commands and/or input formats from killing me
ERROR_HANDLER:
    Call AddChat(RTBColors.ConsoleText, "Error: Command processor has encountered an error.")
    
    ' return command failure result
    ProcessCommand = False
    
    Exit Function
End Function ' end function ProcessCommand

' command processing helper function
Public Function ExecuteCommand(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal Message As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean

    Dim tmpMsg   As String  ' stores copy of message
    Dim cmdName  As String  ' stores command name
    Dim msgData  As String  ' stores unparsed command parameters
    Dim blnNoCmd As Boolean ' stores result of command switch (true = no command found)
    Dim i        As Integer ' loop counter
    
    ' create single command data array element for safe bounds checking
    ' and to help aide in a reduction of command function overhead
    ReDim Preserve cmdRet(0)
    
    ' store local copy of message
    tmpMsg = Message

    ' grab command name & message data
    If (InStr(1, tmpMsg, Space(1), vbBinaryCompare) <> 0) Then
        ' grab command name
        cmdName = Left$(tmpMsg, (InStr(1, tmpMsg, Space(1), _
            vbBinaryCompare) - 1))
        
        ' remove command name (and space) from message
        tmpMsg = Mid$(tmpMsg, Len(cmdName) + 2)
        
        ' grab message data
        msgData = tmpMsg
    Else
        ' grab command name
        cmdName = tmpMsg
    End If
    
    ' convert command name to lcase
    cmdName = LCase$(cmdName)

    ' initial access check
    If ((ValidateAccess(dbAccess, cmdName) = True) Or (InBot = True)) Then
        ' command switch
        Select Case (cmdName)
            Case "quit":                         Call OnQuit(Username, dbAccess, msgData, InBot, cmdRet())
            Case "locktext":                     Call OnLockText(Username, dbAccess, msgData, InBot, cmdRet())
            Case "allowmp3":                     Call OnAllowMp3(Username, dbAccess, msgData, InBot, cmdRet())
            Case "loadwinamp":                   Call OnLoadWinamp(Username, dbAccess, msgData, InBot, cmdRet())
            Case "floodmode", "efp":             Call OnEfp(Username, dbAccess, msgData, InBot, cmdRet())
            Case "home", "joinhome":             Call OnHome(Username, dbAccess, msgData, InBot, cmdRet())
            Case "clan", "c":                    Call OnClan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "peonban":                      Call OnPeonBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "invite":                       Call OnInvite(Username, dbAccess, msgData, InBot, cmdRet())
            Case "setmotd":                      Call OnSetMotd(Username, dbAccess, msgData, InBot, cmdRet())
            Case "where":                        Call OnWhere(Username, dbAccess, msgData, InBot, cmdRet())
            Case "qt", "quiettime":              Call OnQuietTime(Username, dbAccess, msgData, InBot, cmdRet())
            Case "roll":                         Call OnRoll(Username, dbAccess, msgData, InBot, cmdRet())
            Case "sweepban", "cb":               Call OnSweepBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "sweepignore", "cs":            Call OnSweepIgnore(Username, dbAccess, msgData, InBot, cmdRet())
            Case "setname":                      Call OnSetName(Username, dbAccess, msgData, InBot, cmdRet())
            Case "setpass":                      Call OnSetPass(Username, dbAccess, msgData, InBot, cmdRet())
            Case "setkey":                       Call OnSetKey(Username, dbAccess, msgData, InBot, cmdRet())
            Case "setexpkey":                    Call OnSetExpKey(Username, dbAccess, msgData, InBot, cmdRet())
            Case "setserver":                    Call OnSetServer(Username, dbAccess, msgData, InBot, cmdRet())
            Case "giveup", "op":                 Call OnGiveUp(Username, dbAccess, msgData, InBot, cmdRet())
            Case "math", "eval":                 Call OnMath(Username, dbAccess, msgData, InBot, cmdRet())
            Case "idlebans", "ib":               Call OnIdleBans(Username, dbAccess, msgData, InBot, cmdRet())
            Case "chpw":                         Call OnChPw(Username, dbAccess, msgData, InBot, cmdRet())
            Case "join":                         Call OnJoin(Username, dbAccess, msgData, InBot, cmdRet())
            Case "sethome":                      Call OnSetHome(Username, dbAccess, msgData, InBot, cmdRet())
            Case "resign":                       Call OnResign(Username, dbAccess, msgData, InBot, cmdRet())
            Case "cbl", "clearbanlist":          Call OnClearBanList(Username, dbAccess, msgData, InBot, cmdRet())
            Case "koy", "kickonyell":            Call OnKickOnYell(Username, dbAccess, msgData, InBot, cmdRet())
            Case "rejoin", "rj":                 Call OnRejoin(Username, dbAccess, msgData, InBot, cmdRet())
            Case "plugban":                      Call OnPlugBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "clist", "clientbans", "cbans": Call OnClientBans(Username, dbAccess, msgData, InBot, cmdRet())
            Case "setvol":                       Call OnSetVol(Username, dbAccess, msgData, InBot, cmdRet())
            Case "cadd":                         Call OnCAdd(Username, dbAccess, msgData, InBot, cmdRet())
            Case "cdel", "delclient":            Call OnCDel(Username, dbAccess, msgData, InBot, cmdRet())
            Case "banned":                       Call OnBanned(Username, dbAccess, msgData, InBot, cmdRet())
            Case "ipbans":                       Call OnIPBans(Username, dbAccess, msgData, InBot, cmdRet())
            Case "ipban":                        Call OnIPBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "unipban":                      Call OnUnIPBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "designate", "des":             Call OnDesignate(Username, dbAccess, msgData, InBot, cmdRet())
            Case "shuffle":                      Call OnShuffle(Username, dbAccess, msgData, InBot, cmdRet())
            Case "repeat":                       Call OnRepeat(Username, dbAccess, msgData, InBot, cmdRet())
            Case "next":                         Call OnNext(Username, dbAccess, msgData, InBot, cmdRet())
            Case "prev":                         Call OnPrev(Username, dbAccess, msgData, InBot, cmdRet())
            Case "protect":                      Call OnProtect(Username, dbAccess, msgData, InBot, cmdRet())
            Case "whispercmds", "wc":            Call OnWhisperCmds(Username, dbAccess, msgData, InBot, cmdRet())
            Case "stop":                         Call OnStop(Username, dbAccess, msgData, InBot, cmdRet())
            Case "play":                         Call OnPlay(Username, dbAccess, msgData, InBot, cmdRet())
            Case "useitunes":                    Call OnUseiTunes(Username, dbAccess, msgData, InBot, cmdRet())
            Case "usewinamp":                    Call OnUseWinamp(Username, dbAccess, msgData, InBot, cmdRet())
            Case "pause":                        Call OnPause(Username, dbAccess, msgData, InBot, cmdRet())
            Case "fos":                          Call OnFos(Username, dbAccess, msgData, InBot, cmdRet())
            Case "rem", "del":                   Call OnRem(Username, dbAccess, msgData, InBot, cmdRet())
            Case "reconnect":                    Call OnReconnect(Username, dbAccess, msgData, InBot, cmdRet())
            Case "unigpriv":                     Call OnUnIgPriv(Username, dbAccess, msgData, InBot, cmdRet())
            Case "igpriv":                       Call OnIgPriv(Username, dbAccess, msgData, InBot, cmdRet())
            Case "block":                        Call OnBlock(Username, dbAccess, msgData, InBot, cmdRet())
            Case "idletime", "idlewait":         Call OnIdleTime(Username, dbAccess, msgData, InBot, cmdRet())
            Case "idle":                         Call OnIdle(Username, dbAccess, msgData, InBot, cmdRet())
            Case "shitdel":                      Call OnShitDel(Username, dbAccess, msgData, InBot, cmdRet())
            Case "safedel":                      Call OnSafeDel(Username, dbAccess, msgData, InBot, cmdRet())
            Case "tagdel":                       Call OnTagDel(Username, dbAccess, msgData, InBot, cmdRet())
            Case "setidle":                      Call OnSetIdle(Username, dbAccess, msgData, InBot, cmdRet())
            Case "idletype":                     Call OnIdleType(Username, dbAccess, msgData, InBot, cmdRet())
            Case "filter":                       Call OnFilter(Username, dbAccess, msgData, InBot, cmdRet())
            Case "trigger":                      Call OnTrigger(Username, dbAccess, msgData, InBot, cmdRet())
            Case "settrigger":                   Call OnSetTrigger(Username, dbAccess, msgData, InBot, cmdRet())
            Case "levelban":                     Call OnLevelBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "d2levelban":                   Call OnD2LevelBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "pon", "phrasebans on":         Call OnPhraseBans(Username, dbAccess, msgData, InBot, cmdRet())
            Case "poff", "phrasebans off":       Call OnPhraseBans(Username, dbAccess, msgData, InBot, cmdRet())
            Case "cbans":                        Call OnCBans(Username, dbAccess, msgData, InBot, cmdRet())
            Case "pstatus", "phrasebans":        Call OnPhraseBans(Username, dbAccess, msgData, InBot, cmdRet())
            Case "mimic":                        Call OnMimic(Username, dbAccess, msgData, InBot, cmdRet())
            Case "nomimic":                      Call OnNoMimic(Username, dbAccess, msgData, InBot, cmdRet())
            Case "setpmsg":                      Call OnSetPMsg(Username, dbAccess, msgData, InBot, cmdRet())
            Case "phrases", "plist":             Call OnPhrases(Username, dbAccess, msgData, InBot, cmdRet())
            Case "addphrase", "padd":            Call OnAddPhrase(Username, dbAccess, msgData, InBot, cmdRet())
            Case "delphrase", "pdel":            Call OnDelPhrase(Username, dbAccess, msgData, InBot, cmdRet())
            Case "tagban", "addtag", "tagadd":   Call OnTagBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "fadd":                         Call OnFAdd(Username, dbAccess, msgData, InBot, cmdRet())
            Case "frem":                         Call OnFRem(Username, dbAccess, msgData, InBot, cmdRet())
            Case "safelist":                     Call OnSafeList(Username, dbAccess, msgData, InBot, cmdRet())
            Case "safeadd":                      Call OnSafeAdd(Username, dbAccess, msgData, InBot, cmdRet())
            Case "exile":                        Call OnExile(Username, dbAccess, msgData, InBot, cmdRet())
            Case "unexile":                      Call OnUnExile(Username, dbAccess, msgData, InBot, cmdRet())
            Case "shitlist", "sl":               Call OnShitList(Username, dbAccess, msgData, InBot, cmdRet())
            Case "safelist":                     Call OnSafeList(Username, dbAccess, msgData, InBot, cmdRet())
            Case "tagbans":                      Call OnTagBans(Username, dbAccess, msgData, InBot, cmdRet())
            Case "shitadd", "pban":              Call OnShitAdd(Username, dbAccess, msgData, InBot, cmdRet())
            Case "dnd":                          Call OnDND(Username, dbAccess, msgData, InBot, cmdRet())
            Case "bancount":                     Call OnBanCount(Username, dbAccess, msgData, InBot, cmdRet())
            Case "tagcheck":                     Call OnTagCheck(Username, dbAccess, msgData, InBot, cmdRet())
            Case "slcheck", "shitcheck":         Call OnSLCheck(Username, dbAccess, msgData, InBot, cmdRet())
            Case "readfile":                     Call OnReadFile(Username, dbAccess, msgData, InBot, cmdRet())
            Case "levelban", "levelbans":        Call OnLevelBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "d2levelban", "d2levelbans":    Call OnD2LevelBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "greet":                        Call OnGreet(Username, dbAccess, msgData, InBot, cmdRet())
            Case "allseen":                      Call OnAllSeen(Username, dbAccess, msgData, InBot, cmdRet())
            Case "ban":                          Call OnBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "unban":                        Call OnUnBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "kick":                         Call OnKick(Username, dbAccess, msgData, InBot, cmdRet())
            Case "lastwhisper", "lw":            Call OnLastWhisper(Username, dbAccess, msgData, InBot, cmdRet())
            Case "say":                          Call OnSay(Username, dbAccess, msgData, InBot, cmdRet())
            Case "expand":                       Call OnExpand(Username, dbAccess, msgData, InBot, cmdRet())
            Case "detail", "dbd":                Call OnDetail(Username, dbAccess, msgData, InBot, cmdRet())
            Case "info":                         Call OnInfo(Username, dbAccess, msgData, InBot, cmdRet())
            Case "shout":                        Call OnShout(Username, dbAccess, msgData, InBot, cmdRet())
            Case "voteban":                      Call OnVoteBan(Username, dbAccess, msgData, InBot, cmdRet())
            Case "votekick":                     Call OnVoteKick(Username, dbAccess, msgData, InBot, cmdRet())
            Case "vote":                         Call OnVote(Username, dbAccess, msgData, InBot, cmdRet())
            Case "tally":                        Call OnTally(Username, dbAccess, msgData, InBot, cmdRet())
            Case "cancel":                       Call OnCancel(Username, dbAccess, msgData, InBot, cmdRet())
            Case "back":                         Call OnBack(Username, dbAccess, msgData, InBot, cmdRet())
            Case "uptime":                       Call OnUptime(Username, dbAccess, msgData, InBot, cmdRet())
            Case "away":                         Call OnAway(Username, dbAccess, msgData, InBot, cmdRet())
            Case "mp3":                          Call OnMP3(Username, dbAccess, msgData, InBot, cmdRet())
            Case "deldef":                       Call OnDelDef(Username, dbAccess, msgData, InBot, cmdRet())
            Case "define", "def":                Call OnDefine(Username, dbAccess, msgData, InBot, cmdRet())
            Case "newdef":                       Call OnNewDef(Username, dbAccess, msgData, InBot, cmdRet())
            Case "ping":                         Call OnPing(Username, dbAccess, msgData, InBot, cmdRet())
            Case "addquote":                     Call OnAddQuote(Username, dbAccess, msgData, InBot, cmdRet())
            Case "owner":                        Call OnOwner(Username, dbAccess, msgData, InBot, cmdRet())
            Case "ignore", "ign":                Call OnIgnore(Username, dbAccess, msgData, InBot, cmdRet())
            Case "quote":                        Call OnQuote(Username, dbAccess, msgData, InBot, cmdRet())
            Case "unignore":                     Call OnUnignore(Username, dbAccess, msgData, InBot, cmdRet())
            Case "cq":                           Call OnCQ(Username, dbAccess, msgData, InBot, cmdRet())
            Case "scq":                          Call OnSCQ(Username, dbAccess, msgData, InBot, cmdRet())
            Case "time":                         Call OnTime(Username, dbAccess, msgData, InBot, cmdRet())
            Case "getping", "pingme":            Call OnGetPing(Username, dbAccess, msgData, InBot, cmdRet())
            Case "checkmail":                    Call OnCheckMail(Username, dbAccess, msgData, InBot, cmdRet())
            Case "getmail":                      Call OnGetMail(Username, dbAccess, msgData, InBot, cmdRet())
            Case "whoami":                       Call OnWhoAmI(Username, dbAccess, msgData, InBot, cmdRet())
            Case "add", "set":                   Call OnAdd(Username, dbAccess, msgData, InBot, cmdRet())
            Case "mmail":                        Call OnMMail(Username, dbAccess, msgData, InBot, cmdRet())
            Case "bmail", "mail":                Call OnMail(Username, dbAccess, msgData, InBot, cmdRet())
            Case "designated":                   Call OnDesignated(Username, dbAccess, msgData, InBot, cmdRet())
            Case "flip":                         Call OnFlip(Username, dbAccess, msgData, InBot, cmdRet())
            Case "ver", "about", "version":      Call OnAbout(Username, dbAccess, msgData, InBot, cmdRet())
            Case "server":                       Call OnServer(Username, dbAccess, msgData, InBot, cmdRet())
            Case "find", "findr":                Call OnFind(Username, dbAccess, msgData, InBot, cmdRet())
            Case "whois":                        Call OnWhoIs(Username, dbAccess, msgData, InBot, cmdRet())
            Case "findattr", "findflag":         Call OnFindAttr(Username, dbAccess, msgData, InBot, cmdRet())
            Case Else
                blnNoCmd = True
        End Select
        
        ' append entry to command log
        Call LogCommand(Username, Message)
        
        ' was a command found? return.
        ExecuteCommand = (Not (blnNoCmd))
    Else
        ' return false result, as user does not have sufficient
        ' access to issue the requested command
        ExecuteCommand = False
    End If
End Function

' handle quit command
Private Function OnQuit(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Call frmChat.Form_Unload(0)
End Function ' end function OnQuit

' handle locktext command
Private Function OnLockText(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Call frmChat.mnuLock_Click
End Function ' end function OnLockText

' handle allowmp3 command
Private Function OnAllowMp3(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    If (BotVars.DisableMP3Commands) Then
        tmpBuf = "Allowing MP3 commands."
        
        BotVars.DisableMP3Commands = False
    Else
        tmpBuf = "MP3 commands are now disabled."
        
        BotVars.DisableMP3Commands = True
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnAllowMp3

' handle loadwinamp command
Private Function OnLoadWinamp(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    tmpBuf = LoadWinamp(ReadCFG("Other", "WinampPath"))
            
    If (Len(tmpBuf) < 1) Then
        Exit Function
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnLoadWinamp

' handle efp command
Private Function OnEfp(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    If (Left$(msgData, 2) = "on") Then
        ' enable efp
        Call frmChat.SetFloodbotMode(1)
        
        tmpBuf = "Emergency floodbot protection enabled."
     ElseIf (Left$(msgData, 6) = "status") Then
        If (bFlood) Then
            frmChat.AddChat RTBColors.TalkBotUsername, "Emergency floodbot protection is " & _
                "enabled. (No messages can be sent to battle.net.)"
        Else
            tmpBuf = "Emergency floodbot protection is disabled."
        End If
    ElseIf (Left$(msgData, 3) = "off") Then
        ' disable efp
        Call frmChat.SetFloodbotMode(0)
        
        tmpBuf = "Emergency floodbot protection disabled."
    End If
            
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnEfp

' handle home command
Private Function OnHome(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    AddQ "/join " & BotVars.HomeChannel, 1
End Function ' end function OnHome

' handle clan command
Private Function OnClan(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    ' is bot a channel operator?
    If ((MyFlags) And (&H2)) Then
        Select Case (LCase$(msgData))
            Case "public", "pub"
                tmpBuf = "Clan channel is now public."
                
                ' set clan channel to public
                AddQ "/clan public", 1
            Case "private", "priv"
                tmpBuf = "Clan channel is now private."
                
                ' set clan channel to private
                AddQ "/clan private", 1
            Case Else
                tmpBuf = "/clan " & msgData
        End Select
    Else
        tmpBuf = "The bot must have ops to change clan privacy status."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnClan

' handle peonban command
Private Function OnPeonBan(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
            
    Select Case (LCase$(msgData))
        Case "on"
            ' enable peon banning
            BotVars.BanPeons = 1
            
            ' write configuration entry
            WriteINI "Other", "PeonBans", "1"
            
            tmpBuf = "Peon banning activated."
        Case "off"
            ' disable peon banning
            BotVars.BanPeons = 0
            
            ' write configuration entry
            WriteINI "Other", "PeonBans", "0"
            
            tmpBuf = "Peon banning deactivated."
        Case "status"
            tmpBuf = "The bot is currently "
            
            If (BotVars.BanPeons = 0) Then
                tmpBuf = tmpBuf & "not banning peons."
            Else
                tmpBuf = tmpBuf & "banning peons."
            End If
    End Select
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnPeonBan

' handle invite command
Private Function OnInvite(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    If (IsW3) Then
        If (Clan.MyRank >= 3) Then
            Call InviteToClan(msgData)
            
            tmpBuf = msgData & ": Clan invitation sent."
        Else
            tmpBuf = "The bot must hold Shaman or Chieftain rank to invite users."
        End If
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnInvite

' handle setmotd command
Private Function OnSetMotd(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    If (IsW3) Then
        If (Clan.MyRank >= 3) Then
            Call SetClanMOTD(msgData)
            
            tmpBuf = "Clan MOTD set."
        Else
            tmpBuf = "Shaman or Chieftain rank is required to set the MOTD."
        End If
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSetMotd

' handle where command
Private Function OnWhere(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    tmpBuf = "I am currently in channel " & gChannel.Current & " (" & _
        colUsersInChannel.Count & " users present)"
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnWhere

' handle quiettime command
Private Function OnQuietTime(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    Select Case LCase$(msgData)
        Case "on"
            ' enable quiettime
            BotVars.QuietTime = True
        
            ' write configuration entry
            WriteINI "Main", "QuietTime", "Y"
            
            tmpBuf = "Quiet-time enabled."
            
        Case "off"
            ' disable quiettime
            BotVars.QuietTime = False
            
            ' write configuration entry
            WriteINI "Main", "QuietTime", "N"
            
            tmpBuf = "Quiet-time disabled."
            
        Case "status"
            If (BotVars.QuietTime) Then
                tmpBuf = "Quiet-time is currently enabled."
            Else
                tmpBuf = "Quiet-time is currently disabled."
            End If
        
        Case Else
            tmpBuf = "Invalid arguments."
    End Select
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnQuietTime

' handle roll command
Private Function OnRoll(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf  As String ' temporary output buffer
    Dim iWinamp As Long
    Dim Track   As Long

    If (Len(msgData) = 0) Then
        Randomize
        
        iWinamp = CLng(Rnd * 100)
        
        tmpBuf = "Random number (0-100): " & iWinamp
    Else
        Randomize
        
        If (StrictIsNumeric(msgData)) Then
            If (Val(msgData) < 100000000) Then
                Track = CLng(Rnd * CLng(msgData))
                
                tmpBuf = "Random number (0-" & msgData & "): " & Track
            Else
                tmpBuf = "Invalid value."
            End If
        Else
            tmpBuf = "Invalid value."
        End If
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnRoll

' handle sweepban command
Private Function OnSweepBan(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u As String
    Dim Y As String

    Caching = True
    
    Call Cache(vbNullString, 255, "ban ")
    
    Call AddQ("/who " & msgData, 1)
End Function ' end function OnSweepBan

' handle sweepignore command
Private Function OnSweepIgnore(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u As String
    Dim Y As String
    
    Caching = True
    
    Call Cache(vbNullString, 255, "squelch ")
    
    Call AddQ("/who " & msgData, 1)
End Function ' end function OnSweepIgnore

' handle setname command
Private Function OnSetName(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    ' only allow use of setname command while on-line to prevent beta
    ' authorization bypassing
    If ((Not (g_Online = True)) Or (g_Connected = False)) Then
        Exit Function
    End If

    ' write configuration entry
    Call WriteINI("Main", "Username", msgData)
    
    ' set username
    BotVars.Username = msgData
    
    tmpBuf = "New username set."
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSetName

' handle setpass command
Private Function OnSetPass(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    ' write configuration entry
    WriteINI "Main", "Password", msgData
    
    ' set password
    BotVars.Password = msgData
    
    tmpBuf = "New password set."
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSetPass

' handle math command
Private Function OnMath(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    ' default error handler for math command
    On Error GoTo ERROR_HANDLER
    
    Dim tmpBuf As String ' temporary output buffer

    If (Len(msgData) > 0) Then
        If (InStr(1, msgData, "CreateObject", vbTextCompare) > 0) Then
            ' use of CreateObject is a no no
            tmpBuf = "Evaluation error."
        Else
            Dim res As String ' stores result of Eval()
        
            ' disable access to user interface
            frmChat.SCRestricted.AllowUI = False
            
            ' evaluate expression
            res = frmChat.SCRestricted.Eval(msgData)
            
            ' check for scripting object errors
            If (res <> vbNullString) Then
                tmpBuf = res
            Else
                tmpBuf = "Evaluation error."
            End If
        End If
    Else
        tmpBuf = "Evaluation error."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
    
    Exit Function
    
ERROR_HANDLER:
    tmpBuf = "Evaluation error."

    ' return message
    cmdRet(0) = tmpBuf
    
    Exit Function
End Function ' end function OnMath

' handle setkey command
Private Function OnSetKey(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    ' clean data
    msgData = Replace(msgData, "-", vbNullString)
    msgData = Replace(msgData, " ", vbNullString)

    ' write configuration information
    Call WriteINI("Main", "CDKey", msgData)
    
    ' set CD-Key
    BotVars.CDKey = msgData
    
    tmpBuf = "New cdkey set."
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSetKey

' handle setexpkey command
Private Function OnSetExpKey(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    ' clean data
    msgData = Replace(msgData, "-", vbNullString)
    msgData = Replace(msgData, " ", vbNullString)
    
    ' write configuration entry
    Call WriteINI("Main", "LODKey", msgData)
    
    ' set expansion CD-Key
    BotVars.LODKey = msgData
    
    tmpBuf = "New expansion CD-key set."
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSetExpKey

' handle setserver command
Private Function OnSetServer(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    ' write configuration information
    Call WriteINI("Main", "Server", msgData)
    
    ' set server
    BotVars.Server = msgData
    
    tmpBuf = "New server set."
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSetServer

' handle giveup command
Private Function OnGiveUp(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    If (CheckChannel(msgData) > 0) Then
        ' designate user
        Call AddQ("/designate " & IIf(Dii, "*", vbNullString) & msgData)
        
        ' rejoin channel
        Call AddQ("/resign")
    End If
End Function ' end function OnGiveUp

' handle idlebans command
Private Function OnIdleBans(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim strArray() As String ' ...
    Dim tmpBuf     As String ' temporary output buffer
    Dim subCmd     As String
    
    subCmd = LCase$(Mid$(msgData, 1, InStr(1, msgData, Space$(1), vbBinaryCompare)))
    
    If (Len(subCmd) > 0) Then
        Select Case (subCmd)
            Case "on"
                strArray() = Split(msgData, " ")
                
                BotVars.IB_On = BTRUE
                
                If (UBound(strArray) > 1) Then
                    If (StrictIsNumeric(strArray(2))) Then
                        BotVars.IB_Wait = strArray(2)
                    End If
                End If
                
                If (BotVars.IB_Wait > 0) Then
                    tmpBuf = "IdleBans activated, with a delay of " & BotVars.IB_Wait & "."
                    
                    WriteINI "Other", "IdleBans", "Y"
                    WriteINI "Other", "IdleBanDelay", BotVars.IB_Wait
                Else
                    BotVars.IB_Wait = 400
                    
                    tmpBuf = "IdleBans activated, using the default delay of 400."
                    
                    WriteINI "Other", "IdleBanDelay", "400"
                    WriteINI "Other", "IdleBans", "Y"
                End If
                
            Case "off"
                BotVars.IB_On = BFALSE
                
                tmpBuf = "IdleBans deactivated."
                
                WriteINI "Other", "IdleBans", "N"
            
            Case "wait", "delay"
                strArray() = Split(msgData, " ")
            
                If (StrictIsNumeric(strArray(1))) Then
                    BotVars.IB_Wait = CInt(strArray(1))
                    
                    tmpBuf = "IdleBan delay set to " & BotVars.IB_Wait & "."
                    
                    WriteINI "Other", "IdleBanDelay", CInt(strArray(1))
                Else
                    tmpBuf = "IdleBan delays require a numeric value."
                End If
                
            Case "kick"
                strArray() = Split(msgData, " ")
            
                If (UBound(strArray) > 1) Then
                    Select Case (LCase$(strArray(1)))
                        Case "on"
                            tmpBuf = "Idle users will now be kicked instead of banned."
                            
                            WriteINI "Other", "KickIdle", "Y"
                            
                            BotVars.IB_Kick = True
                            
                        Case "off"
                            tmpBuf = "Idle users will now be banned instead of kicked."
                            
                            WriteINI "Other", "KickIdle", "N"
                            
                            BotVars.IB_Kick = False
                            
                        Case Else
                            tmpBuf = "Unknown idle kick setting."
                    End Select
                Else
                    tmpBuf = "Not enough arguments were supplied."
                End If
                
            Case "status"
                If (BotVars.IB_On = BTRUE) Then
                    tmpBuf = IIf(BotVars.IB_Kick, "Kicking", "Banning") & _
                        " users who are idle for " & BotVars.IB_Wait & "+ seconds."
                Else
                    tmpBuf = "IdleBans are disabled."
                End If
                
            Case Else
                tmpBuf = "Invalid IdleBan command."
        End Select
    Else
        tmpBuf = "Invalid IdleBan command arguments."
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnIdleBans

' handle chpw command
Private Function OnChPw(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim strArray() As String
    Dim tmpBuf     As String ' temporary output buffer
    
    strArray = Split(msgData, " ")
    
    If (UBound(strArray) > 0) Then
        Select Case (strArray(0))
            Case "on", "set"
                BotVars.ChannelPassword = strArray(2)
                
                If (BotVars.ChannelPasswordDelay < 1) Then
                    BotVars.ChannelPasswordDelay = 30
                    
                    tmpBuf = "Channel password protection enabled, delay set to " & _
                        BotVars.ChannelPasswordDelay & "."
                Else
                    tmpBuf = "Channel password protection enabled."
                End If
                
            Case "time", "delay", "wait"
                If (StrictIsNumeric(strArray(1))) Then
                    If (Val(strArray(1)) < 256) Then
                        BotVars.ChannelPasswordDelay = CByte(strArray(1))
                        
                        tmpBuf = "Channel password delay set to " & strArray(1) & "."
                    Else
                        tmpBuf = "Channel password delays cannot be more than 255 seconds."
                    End If
                Else
                    tmpBuf = "Time setting requires a numeric value."
                End If
                
            Case "off", "kill", "clear"
                BotVars.ChannelPassword = vbNullString
                
                BotVars.ChannelPasswordDelay = 0
                
                tmpBuf = "Channel password protection disabled."
                
            Case "info", "status"
                If ((BotVars.ChannelPassword = vbNullString) Or _
                    (BotVars.ChannelPasswordDelay = 0)) Then
                    
                    tmpBuf = "Channel password protection is disabled."
                Else
                    tmpBuf = "Channel password protection is enabled. Password [" & BotVars.ChannelPassword & "], Delay [" & _
                        BotVars.ChannelPasswordDelay & "]."
                End If
                
            Case Else
                tmpBuf = "Unknown channel password command."
        End Select
    Else
        tmpBuf = "Error setting channel password."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnChPw

' handle join command
Private Function OnJoin(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    If (LenB(msgData) > 0) Then
        AddQ "/join " & msgData
    Else
        tmpBuf = "Join what channel?"
    End If
End Function ' end function OnJoin

' handle sethome command
Private Function OnSetHome(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    WriteINI "Main", "HomeChan", msgData
    
    BotVars.HomeChannel = msgData
    
    tmpBuf = "Home channel set to [ " & msgData & " ]"
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSetHome

' handle resign command
Private Function OnResign(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    AddQ "/resign", 1
End Function ' end function OnResign

' handle clearbanlist
Private Function OnClearBanList(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    ReDim gBans(0)
    
    tmpBuf = "Banned user list cleared."
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnClearBanList

' handle kickonyell command
Private Function OnKickOnYell(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    Select Case (LCase$(msgData))
        Case "on"
            BotVars.KickOnYell = 1
            
            tmpBuf = "Kick-on-yell enabled."
            
        Case "off"
            BotVars.KickOnYell = 0
            
            tmpBuf = "Kick-on-yell disabled."
            
        Case "status"
            tmpBuf = "Kick-on-yell is "
            tmpBuf = tmpBuf & IIf(BotVars.KickOnYell = 1, "enabled", "disabled") & "."
    End Select
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnKickOnYell

' handle rejoin command
Private Function OnRejoin(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    AddQ "/join " & CurrentUsername & " Rejoin", 1
    AddQ "/join " & gChannel.Current, 1
End Function ' end function OnRejoin

' handle plugban command
Private Function OnPlugBan(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    Select Case (LCase$(msgData))
        Case "on"
            Dim i As Integer
        
            If (BotVars.PlugBan) Then
                tmpBuf = "PlugBan is already activated."
            Else
                BotVars.PlugBan = True
                
                tmpBuf = "PlugBan activated."
                
                For i = 1 To colUsersInChannel.Count
                    With colUsersInChannel.Item(i)
                        If ((.Flags = 16) And (Not .Safelisted)) Then
                            AddQ "/ban " & IIf(Dii, "*", "") & .Username & " PlugBan", 1
                        End If
                    End With
                Next i
            End If
            
        Case "off"
            If (BotVars.PlugBan) Then
                BotVars.PlugBan = False
                
                tmpBuf = "PlugBan deactivated."
            Else
                tmpBuf = "PlugBan is already deactivated."
            End If
            
        Case "status"
            If (BotVars.PlugBan) Then
                tmpBuf = "PlugBan is activated."
            Else
                tmpBuf = "PlugBan is deactivated."
            End If
    End Select

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnPlugBan

' handle clientbans command
Private Function OnClientBans(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf() As String ' temporary output buffer
    Dim tmpCount As Integer
    Dim BanCount As Integer
    Dim i        As Integer
    
    ReDim Preserve tmpBuf(0)
    
    tmpBuf(tmpCount) = "Clientbans: "

    For i = LBound(ClientBans()) To UBound(ClientBans())
        If (ClientBans(i) <> vbNullString) Then
            tmpBuf(tmpCount) = tmpBuf(tmpCount) & ", " & ClientBans(i)
            
            If (Len(tmpBuf(tmpCount)) > 90) Then
                ' increase array size
                ReDim Preserve tmpBuf(tmpCount + 1)
                
                tmpBuf(tmpCount) = Replace(tmpBuf(tmpCount), " , ", Space(1)) & _
                    " [more]"
                    
                ' increment counter
                tmpCount = (tmpCount + 1)
            End If
            
            ' increment counter
            BanCount = (BanCount + 1)
        End If
    Next i

    If (BanCount = 0) Then
        tmpBuf(tmpCount) = "There are currently no client bans."
    Else
        tmpBuf(tmpCount) = Replace(tmpBuf(tmpCount), " , ", Space(1))
    End If
    
    ' return message
    cmdRet() = tmpBuf()
End Function ' end function OnClientBans

' handle setvol command
Private Function OnSetVol(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    Dim hWndWA As Long

    If (Not (BotVars.DisableMP3Commands)) Then
        If (StrictIsNumeric(msgData)) Then
            hWndWA = GetWinamphWnd()
            
            If (hWndWA = 0) Then
                tmpBuf = "Winamp is not loaded."
            End If
            
            If (CInt(msgData) > 100) Then
                msgData = 100
            End If
            
            Call SendMessage(hWndWA, WM_WA_IPC, 2.55 * CInt(msgData), 122)
            
            tmpBuf = "Volume set to " & msgData & "%."
        Else
            tmpBuf = "Invalid volume level (0-100)."
        End If
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSetVol

' handle cadd command
Private Function OnCAdd(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf     As String ' temporary output buffer
    Dim cBans      As String
    Dim strArray() As String
    Dim i          As Integer

    If (Len(msgData) > 0) Then
        ' grab client bans from file
        cBans = UCase$(ReadCFG("Other", "ClientBans"))
        
        ' postfix new ban(s) to current listing
        cBans = cBans & Space(1) & UCase$(msgData)
        
        ' write client bans to file
        WriteINI "Other", "ClientBans", UCase$(cBans)
        
        ' write client bans to memory
        If (InStr(1, msgData, Space(1), vbBinaryCompare) = 0) Then
            ReDim Preserve ClientBans(0 To UBound(ClientBans) + 1)
                
            ClientBans(UBound(ClientBans)) = UCase$(msgData)
        Else
            strArray() = Split(msgData, " ")
            
            For i = LBound(strArray) To UBound(strArray)
                ReDim Preserve ClientBans(0 To UBound(ClientBans) + 1)
                
                ClientBans(UBound(ClientBans)) = UCase$(strArray(i))
            Next i
        End If
        
        tmpBuf = "Added clientban(s): " & UCase$(msgData)
    Else
        tmpBuf = "You must enter a client to ban."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnCAdd

' handle cdel command
Private Function OnCDel(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    Dim i      As Integer
    Dim cBans  As String
    
    For i = LBound(ClientBans) To UBound(ClientBans)
        cBans = cBans & UCase$(ClientBans(i)) & " "
    Next i
    
    If (InStr(1, cBans, msgData, vbBinaryCompare) <> 0) Then
        cBans = Replace(cBans, msgData, vbNullString)
        
        WriteINI "Other", "ClientBans", Replace(cBans, "  ", vbNullString)
        
        ClientBans() = Split(ReadCFG("Other", "ClientBans"), " ")
        
        If (UBound(ClientBans) = -1) Then
            ReDim ClientBans(0)
        End If
        
        tmpBuf = "Clientban """ & UCase$(msgData) & """ deleted."
    Else
        tmpBuf = "Client is not banned."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnCDel

' handle banned command
Private Function OnBanned(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf() As String ' temporary output buffer
    Dim tmpCount As Integer
    Dim BanCount As Integer
    Dim i        As Integer
    
    ReDim Preserve tmpBuf(0)

    tmpBuf(tmpCount) = "Banned users: "
    
    For i = LBound(gBans) To UBound(gBans)
        If (gBans(i).Username <> vbNullString) Then
            tmpBuf(tmpCount) = tmpBuf(tmpCount) & ", " & gBans(i).Username
            
            If ((Len(tmpBuf(tmpCount)) > 90) And (i <> UBound(gBans))) Then
                ' increase array size
                ReDim Preserve tmpBuf(tmpCount + 1)
            
                ' apply postfix to previous line
                tmpBuf(tmpCount) = Replace(tmpBuf(tmpCount), " , ", Space(1)) & " [more]"
                
                ' apply prefix to new line
                tmpBuf(tmpCount + 1) = "Banned users: "
                
                ' incrememnt counter
                tmpCount = (tmpCount + 1)
            End If
            
            ' incrememnt counter
            BanCount = (BanCount + 1)
        End If
    Next i

    If (BanCount = 0) Then
        tmpBuf(tmpCount) = "No users have been banned."
    Else
        tmpBuf(tmpCount) = Replace(tmpBuf(tmpCount), " , ", Space(1))
    End If
    
    ' return message
    cmdRet() = tmpBuf()
End Function ' end function OnBanned

' handle ipbans command
Private Function OnIPBans(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim i      As Integer
    Dim tmpBuf As String ' temporary output buffer

    If (Left$(msgData, 2)) = "on" Then
        BotVars.IPBans = True
        
        WriteINI "Other", "IPBans", "Y"
        
        tmpBuf = "IPBanning activated."
        
        If ((MyFlags = 2) Or (MyFlags = 18)) Then
            For i = 1 To colUsersInChannel.Count
                Select Case colUsersInChannel.Item(i).Flags
                    Case 20, 30, 32, 48
                        AddQ "/ban " & IIf(Dii, "*", "") & colUsersInChannel.Item(i).Username & _
                            " IPBanned.", 1
                End Select
            Next i
        End If
    ElseIf (Left$(msgData, 3) = "off") Then
        BotVars.IPBans = False
        
        WriteINI "Other", "IPBans", "N"
        
        tmpBuf = "IPBanning deactivated."
        
    ElseIf (Left$(msgData, 6) = "status") Then
        If (BotVars.IPBans) Then
            tmpBuf = "IPBanning is currently active."
        Else
            tmpBuf = "IPBanning is currently disabled."
        End If
    Else
        tmpBuf = "Unrecognized IPBan command. Use 'on', 'off' or 'status'."
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnIPBans

' handle ipban command
Private Function OnIPBan(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim gAcc     As udtGetAccessResponse

    Dim tmpBuf   As String ' temporary output buffer

    msgData = StripInvalidNameChars(msgData)

    If (Len(msgData) > 0) Then
        If (InStr(1, msgData, "@") > 0) Then
            msgData = StripRealm(msgData)
        End If
        
        If (dbAccess.Access < 101) Then
            If ((GetSafelist(msgData)) Or (GetSafelist(msgData))) Then
                ' return message
                cmdRet(0) = "That user is safelisted."
                
                Exit Function
            End If
        End If
        
        gAcc = GetAccess(msgData)
        
        If ((gAcc.Access >= dbAccess.Access) Or _
            ((InStr(gAcc.Flags, "A") > 0) And (dbAccess.Access < 101))) Then

            tmpBuf = "You do not have enough access to do that."
        Else
            AddQ "/squelch " & IIf(Dii, "*", "") & msgData, 1
        
            tmpBuf = "User " & Chr(34) & msgData & Chr(34) & " IPBanned."
        End If
    Else
        ' return message
        tmpBuf = "You do not have enough access to do that."
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnIPBan

' handle unipban command
Private Function OnUnIPBan(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    If (Len(msgData) > 0) Then
        Call AddQ("/unsquelch " & IIf(Dii, "*", "") & msgData, 1)
        Call AddQ("/unban " & IIf(Dii, "*", "") & msgData, 1)
        
        tmpBuf = "User " & Chr(34) & msgData & Chr(34) & " Un-IPBanned."
    Else
        tmpBuf = "Un-IPBan who?"
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnUnIPBan

' handle designate command
Private Function OnDesignate(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    If (Len(msgData) > 0) Then
        If (((MyFlags) And (&H2)) = &H2) Then
            'diablo 2 handling
            If (Dii = True) Then
                If (Not (Mid$(msgData, 1, 1) = "*")) Then
                    msgData = "*" & msgData
                End If
            End If
            
            Call AddQ("/designate " & msgData, 1)
            
            tmpBuf = "I have designated [ " & msgData & " ]"
        Else
            tmpBuf = "The bot does not have ops."
        End If
    Else
        tmpBuf = "Designate who?"
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnDesignate

' handle shuffle command
Private Function OnShuffle(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    Dim hWndWA As Long
    
    If (Not (BotVars.DisableMP3Commands)) Then
        tmpBuf = "Winamp's Shuffle feature has been toggled."
        
        hWndWA = GetWinamphWnd()
        
        If (hWndWA = 0) Then
            tmpBuf = "Winamp is not loaded."
        Else
            Call SendMessage(hWndWA, WM_COMMAND, WA_TOGGLESHUFFLE, 0)
        End If
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnShuffle

' handle repeat command
Private Function OnRepeat(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim hWndWA As Long
    Dim tmpBuf As String ' temporary output buffer
    
    If (Not (BotVars.DisableMP3Commands)) Then
        tmpBuf = "Winamp's Repeat feature has been toggled."
        
        hWndWA = GetWinamphWnd()
        
        If (hWndWA = 0) Then
            tmpBuf = "Winamp is not loaded."
        Else
            Call SendMessage(hWndWA, WM_COMMAND, WA_TOGGLEREPEAT, 0)
        End If
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnRepeat

' handle next command
Private Function OnNext(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    Dim hWndWA As Long

    If (Not (BotVars.DisableMP3Commands)) Then
        If (iTunesReady) Then
            iTunesNext
            
            tmpBuf = "Skipped forwards."
        Else
            hWndWA = GetWinamphWnd()
            
            If (hWndWA = 0) Then
               tmpBuf = "Winamp is not loaded."
            End If
        
            Call SendMessage(hWndWA, WM_COMMAND, WA_NEXTTRACK, 0)
            
            tmpBuf = "Skipped forwards."
        End If
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnNext

' handle prev command
Private Function OnPrev(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    Dim hWndWA As Long

    If (Not (BotVars.DisableMP3Commands)) Then
        If (iTunesReady) Then
            iTunesBack
            
            tmpBuf = "Skipped backwards."
        Else
            hWndWA = GetWinamphWnd()
            
            If (hWndWA = 0) Then
               tmpBuf = "Winamp is not loaded."
            End If
            
            Call SendMessage(hWndWA, WM_COMMAND, WA_PREVTRACK, 0)
            
            tmpBuf = "Skipped backwards."
        End If
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnPrev

' handle protect command
Private Function OnProtect(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    Select Case (LCase$(msgData))
        Case "on"
            If ((MyFlags = 2) Or (MyFlags = 18)) Then
                Protect = True
                
                tmpBuf = "Lockdown activated by " & Username & "."
                
                Call WildCardBan("*", ProtectMsg, 1)
                
                Call WriteINI("Main", "Protect", "Y")
            Else
                tmpBuf = "The bot does not have ops."
            End If
        
        Case "off"
            If (Protect) Then
                Protect = False
                
                tmpBuf = "Lockdown deactivated."
                
                Call WriteINI("Main", "Protect", "N")
            Else
                tmpBuf = "Protection was not enabled."
            End If
            
        Case "status"
            Select Case (Protect)
                Case True: tmpBuf = "Lockdown is currently active."
                Case Else: tmpBuf = "Lockdown is currently disabled."
            End Select
    End Select
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnProtect

' handle whispercmds command
Private Function OnWhisperCmds(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    If (StrComp(msgData, "status", vbTextCompare) = 0) Then
        tmpBuf = "Command responses will be " & _
            IIf(BotVars.WhisperCmds, "whispered back", "displayed publicly") & "."
    Else
        If (BotVars.WhisperCmds) Then
            BotVars.WhisperCmds = False
            
            Call WriteINI("Main", "WhisperBack", "N")
            
            tmpBuf = "Command responses will now be displayed publicly."
        Else
            BotVars.WhisperCmds = True

            Call WriteINI("Main", "WhisperBack", "Y")
            
            tmpBuf = "Command responses will now be whispered back."
        End If
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnWhisperCmds

' handle stop command
Private Function OnStop(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    Dim hWndWA As Long
    
    If (Not (BotVars.DisableMP3Commands)) Then
        If (iTunesReady) Then
            iTunesStop
            
            tmpBuf = "iTunes playback stopped."
        Else
            hWndWA = GetWinamphWnd()
            
            If (hWndWA = 0) Then
               tmpBuf = "Winamp is not loaded."
            End If
            
            Call SendMessage(hWndWA, WM_COMMAND, WA_STOP, 0)
            
            tmpBuf = "Stopped play."
        End If
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnStop

' handle play command
Private Function OnPlay(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf  As String ' temporary output buffer
    Dim hWndWA  As Long
    Dim Track   As Long
    Dim iWinamp As Long
    
    If (Len(msgData) > 0) Then
        If (Not (BotVars.DisableMP3Commands)) Then
            If (iTunesReady) Then
                iTunesPlayFile Mid$(msgData, 7)
                
                tmpBuf = "Attempted to play the specified filepath."
            Else
                hWndWA = GetWinamphWnd()
                
                If (hWndWA = 0) Then
                    tmpBuf = "Winamp is stopped, or isn't running."
                End If
                
                If (StrictIsNumeric(msgData)) Then
                    Track = CInt(msgData)
                    
                    Call SendMessage(hWndWA, WM_COMMAND, WA_STOP, 0)
                    Call SendMessage(hWndWA, WM_USER, Track - 1, 121)
                    Call SendMessage(hWndWA, WM_COMMAND, WA_PLAY, 0)
                    
                    tmpBuf = "Skipped to track " & Track & "."
                Else
                    Call WinampJumpToFile(msgData)
                End If
            End If
        End If
    Else
        If (Not (BotVars.DisableMP3Commands)) Then
            If (iTunesReady) Then
                iTunesPlay
                
                tmpBuf = "iTunes playback started."
            Else
                hWndWA = GetWinamphWnd()
        
                If (hWndWA = 0) Then
                   tmpBuf = "Winamp is not loaded."
                End If
        
                Call SendMessage(hWndWA, WM_COMMAND, WA_PLAY, 0)
        
                tmpBuf = "Skipped backwards."
        
                If (iWinamp = 0) Then
                    tmpBuf = "Play started."
                Else
                    tmpBuf = "Error sending your command to Winamp. Make sure it's running."
                End If
            End If
        End If
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnPlay

' handle useitunes command
Private Function OnUseiTunes(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    If (iTunesReady) Then
        tmpBuf = "iTunes is already ready."
    Else
        If (InitITunes) Then
            tmpBuf = "iTunes is ready."
        Else
            tmpBuf = "Error launching iTunes."
        End If
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnUseiTunes

' handle usewinamp command
Private Function OnUseWinamp(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    If (iTunesReady) Then
        tmpBuf = "Returning to Winamp control."
        
        iTunesUnready
    Else
        tmpBuf = "iTunes was not ready."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnUseWinamp

' handle pause command
Private Function OnPause(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    Dim hWndWA As Long
    
    If (Not (BotVars.DisableMP3Commands)) Then
        If (iTunesReady) Then
            iTunesPause
            
            tmpBuf = "Pause toggled."
        Else
            hWndWA = GetWinamphWnd()
            
            If (hWndWA = 0) Then
               tmpBuf = "Winamp is not loaded."
            End If
            
            Call SendMessage(hWndWA, WM_COMMAND, WA_PAUSE, 0)
            
            tmpBuf = "Paused/resumed play."
        End If
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnPause

' handle fos command
Private Function OnFos(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim hWndWA As Long
    Dim tmpBuf As String ' temporary output buffer

   If (Not (BotVars.DisableMP3Commands)) Then
        hWndWA = GetWinamphWnd()
        
        If (hWndWA = 0) Then
           tmpBuf = "Winamp is not loaded."
        End If
        
        Call SendMessage(hWndWA, WM_COMMAND, WA_FADEOUTSTOP, 0)
        
        tmpBuf = "Fade-out stop."
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnFos

' handle rem command
Private Function OnRem(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer

    u = msgData
    
    If (Len(u) > 0) Then
        If ((GetAccess(u).Access = -1) And _
            (GetAccess(u).Flags = vbNullString)) Then
            
            tmpBuf = "User not found."
        ElseIf (GetAccess(u).Access >= dbAccess.Access) Then
            tmpBuf = "That user has higher or equal access."
        ElseIf (InStr(1, GetAccess(u).Flags, "L") > 0) Then
            If ((InStr(1, GetAccess(Username).Flags, "A") = 0) And _
                (GetAccess(Username).Access < 100) And (Not (InBot))) Then
            
                tmpBuf = "That user is Locked."
            End If
        Else
            tmpBuf = RemoveItem(u, "users")
            tmpBuf = Replace(tmpBuf, "%msgex%", "userlist entry")
            
            If (InStr(tmpBuf, "Successfully")) Then
                If (BotVars.LogDBActions) Then
                    Call LogDBAction(RemEntry, Username, u, msgData)
                End If
            End If
            
            Call LoadDatabase
        End If
    Else
        tmpBuf = "Remove what user?"
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnRem

' handle reconnect command
Private Function OnReconnect(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    If (g_Online) Then
        BotVars.HomeChannel = gChannel.Current
        
        Call frmChat.DoDisconnect
        
        frmChat.AddChat RTBColors.ErrorMessageText, "[BNET] Reconnecting by command, please wait..."
        
        Pause 1
        
        frmChat.AddChat RTBColors.SuccessText, "Connection initialized."
        
        Call frmChat.DoConnect
    Else
        frmChat.AddChat RTBColors.ErrorMessageText, "You must be online to reconnect. Try connecting first."
    End If
End Function ' end function OnReconnect

' handle unigpriv command
Private Function OnUnIgPriv(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    AddQ "/o unigpriv", 1
    
    tmpBuf = "Recieving text from non-friends."
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnUnIgPriv

' handle igpriv command
Private Function OnIgPriv(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    AddQ "/o igpriv", 1
    
    tmpBuf = "Ignoring text from non-friends."
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnIgPriv

' handle block command
Private Function OnBlock(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer
    Dim z      As String
    Dim i      As Integer

    u = msgData
    
    z = ReadINI("BlockList", "Total", "filters.ini")
    
    If (StrictIsNumeric(z)) Then
        i = z
    Else
        Call WriteINI("BlockList", "Total", "Total=0", "filters.ini")
        
        i = 0
    End If
    
    Call WriteINI("BlockList", "Filter" & (i + 1), u, "filters.ini")
    Call WriteINI("BlockList", "Total", i + 1, "filters.ini")
    
    tmpBuf = "Added """ & u & """ to the username block list."
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnBlock

' handle idletime command
Private Function OnIdleTime(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer

    u = msgData
        
    If ((Not (StrictIsNumeric(u))) Or (Val(u) > 50000)) Then
        tmpBuf = "Error setting idle wait time."
    Else
        Call WriteINI("Main", "IdleWait", 2 * Int(u))
        
        tmpBuf = "Idle wait time set to " & Int(u) & " minutes."
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnIdleTime

' handle idle command
Private Function OnIdle(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean

    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer
        
    u = msgData
    
    If (LCase$(u) = "on") Then
        Call WriteINI("Main", "Idles", "Y")
        
        tmpBuf = "Idles activated."
    ElseIf (LCase$(u) = "off") Then
        Call WriteINI("Main", "Idles", "N")
        
        tmpBuf = "Idles deactivated."
    ElseIf (LCase$(u) = "kick") Then
        If (InStr(1, msgData, Space(1), vbBinaryCompare) = 0) Then
            tmpBuf = "Error setting idles. Make sure you used '.idle on' or '.idle off'."
        Else
            u = Mid$(msgData, InStr(1, msgData, Space(1)) + 1)
            
            If (LCase$(u) = "on") Then
                BotVars.IB_Kick = True
                
                tmpBuf = "Idle kick is now enabled."
            ElseIf (LCase$(u) = "off") Then
                BotVars.IB_Kick = False
                
                tmpBuf = "Idle kick disabled."
            Else
                tmpBuf = "Unknown idle kick command."
            End If
        End If
    Else
        tmpBuf = "Error setting idles. Make sure you used '.idle on' or '.idle off'."
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnIdle

' handle shitdel command
Private Function OnShitDel(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean

    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer
    
    u = msgData
    
    If ((MyFlags = 2) Or (MyFlags = 18)) Then
        Call AddQ("/unban " & IIf(Dii, "*", "") & u, 1)
    End If
    
    tmpBuf = RemoveItem(u, "autobans")
    tmpBuf = Replace(tmpBuf, "%msgex%", "shitlist")
    
    If (InStr(tmpBuf, "Successfully")) Then
        If (BotVars.LogDBActions) Then
            Call LogDBAction(RemEntry, Username, u, msgData)
        End If
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnShitDel

' handle safedel command
Private Function OnSafeDel(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim b      As Boolean
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer

    u = msgData
        
    b = RemoveFromSafelist(u)
    
    If (b) Then
        tmpBuf = "That user has been removed from the safelist."
    Else
        tmpBuf = "That user is not safelisted, or there was an error removing them."
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSafeDel

' handle tagdel command
Private Function OnTagDel(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer
    
    u = msgData
    
    If (Len(u) > 0) Then
        tmpBuf = RemoveItem(u, "tagbans")
        tmpBuf = Replace(tmpBuf, "%msgex%", "tagban")
    Else
        tmpBuf = "Delete what tag?"
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnTagDel
        
' handle profile command
Private Function OnProfile(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim PPL    As Boolean
    Dim tmpBuf As String ' temporary output buffer
    
    u = msgData
    
    If (Len(u) > 0) Then
        PPL = True
    
        'If ((BotVars.WhisperCmds Or WhisperedIn) And _
        '    (Not (PublicOutput))) Then
        '
        '    PPLRespondTo = Username
        'End If
        
        Call RequestProfile(u)
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnProfile

' handle setidle command
Private Function OnSetIdle(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer
    
    u = msgData
    
    If (Len(u) > 0) Then
        If (Left$(u, 1) = "/") Then
            u = " " & u
        End If
        
        Call WriteINI("Main", "IdleMsg", u)
        
        tmpBuf = "Idle message set."
    Else
        tmpBuf = "What do you want the idle message set to?"
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSetIdle

' handle idletype command
Private Function OnIdleType(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer
        
    u = msgData
    
    If ((LCase$(u) = "msg") Or (LCase$(u) = "message")) Then
        Call WriteINI("Main", "IdleType", "msg")
        
        tmpBuf = "Idle type set to [ msg ]."
    ElseIf ((LCase$(u) = "quote") Or (LCase$(u) = "quotes")) Then
        Call WriteINI("Main", "IdleType", "quote")
        
        tmpBuf = "Idle type set to [ quote ]."
    ElseIf (LCase$(u) = "uptime") Then
        Call WriteINI("Main", "IdleType", "uptime")
        
        tmpBuf = "Idle type set to [ uptime ]."
    ElseIf (LCase$(u) = "mp3") Then
        Call WriteINI("Main", "IdleType", "mp3")
        
        tmpBuf = "Idle type set to [ mp3 ]."
    Else
        tmpBuf = "Error setting idle type. The types are [ message quote uptime mp3 ]."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnIdleType

' handle filter command
Private Function OnFilter(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim i      As Integer
    Dim tmpBuf As String ' temporary output buffer
    Dim z      As String

    u = msgData
    
    z = ReadINI("TextFilters", "Total", "filters.ini")
    
    If (StrictIsNumeric(z)) Then
        i = z
    Else
        Call WriteINI("TextFilters", "Total", "Total=0", "filters.ini")
        
        i = 0
    End If
    
    Call WriteINI("TextFilters", "Filter" & (i + 1), u, "filters.ini")
    Call WriteINI("TextFilters", "Total", i + 1, "filters.ini")
    
    ReDim Preserve gFilters(UBound(gFilters) + 1)
    
    gFilters(UBound(gFilters)) = u
    
    tmpBuf = "Added " & Chr(34) & u & Chr(34) & " to the text message filter list."
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnFilter

' handle trigger command
Private Function OnTrigger(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    If (Len(BotVars.Trigger) = 1) Then
        tmpBuf = "The bot's current trigger is " & Chr(34) & Space(1) & _
            BotVars.Trigger & Space(1) & Chr(34) & " (Alt + 0" & Asc(BotVars.Trigger) & ")"
    Else
        tmpBuf = "The bot's current trigger is " & Chr(34) & Space(1) & _
            BotVars.Trigger & Space(1) & Chr(34) & " (Length: " & Len(BotVars.Trigger) & ")"
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnTrigger

' handle settrigger command
Private Function OnSetTrigger(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf     As String ' temporary output buffer
    Dim newTrigger As String
    
    newTrigger = msgData
    
    If (Len(newTrigger) > 0) Then
        If (Left$(newTrigger, 1) <> "/") Then
            BotVars.Trigger = newTrigger
        
            Call WriteINI("Main", "Trigger", newTrigger)
        
            tmpBuf = "The new trigger is " & Chr(34) & newTrigger & Chr(34) & "."
        Else
            tmpBuf = "Invalid trigger."
        End If
    Else
        tmpBuf = "Change to what trigger?"
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSetTrigger

' handle levelban command
Private Function OnLevelBan(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim i      As Integer
    Dim tmpBuf As String ' temporary output buffer
    
    If (Len(msgData) > 0) Then
        If (StrictIsNumeric(msgData)) Then
            i = msgData
            
            If (i > 0) Then
                tmpBuf = "Banning Warcraft III users under level " & i & "."
                
                BotVars.BanUnderLevel = i
            Else
                tmpBuf = "Levelbans disabled."
                
                BotVars.BanUnderLevel = 0
            End If
        Else
            BotVars.BanUnderLevel = 0
            
            tmpBuf = "Levelbans disabled."
        End If
        
        Call WriteINI("Other", "BanUnderLevel", BotVars.BanUnderLevel)
    Else
        If (BotVars.BanUnderLevel = 0) Then
           tmpBuf = "Currently not banning Warcraft III users by level."
        Else
           tmpBuf = "Currently banning Warcraft III users under level " & BotVars.BanUnderLevel & "."
        End If
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnLevelBan

' handle d2levelban command
Private Function OnD2LevelBan(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim i      As Integer
    Dim tmpBuf As String ' temporary output buffer
    
    If (Len(msgData) > 0) Then
        If (StrictIsNumeric(msgData)) Then
            i = Val(msgData)
            
            BotVars.BanD2UnderLevel = i
            
            If (i > 0) Then
                tmpBuf = "Banning Diablo II characters under level " & i & "."
                
                BotVars.BanD2UnderLevel = i
            Else
                tmpBuf = "Diablo II Levelbans disabled."
                
                BotVars.BanD2UnderLevel = 0
            End If
        Else
            tmpBuf = "Diablo II Levelbans disabled."
            
            BotVars.BanD2UnderLevel = 0
        End If
        
        Call WriteINI("Other", "BanD2UnderLevel", BotVars.BanD2UnderLevel)
    Else
    
        If (BotVars.BanD2UnderLevel = 0) Then
           tmpBuf = "Currently not banning Diablo II users by level."
        Else
           tmpBuf = "Currently banning Diablo II users under level " & BotVars.BanD2UnderLevel & "."
        End If
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnD2LevelBans

' handle phrasebans command
Private Function OnPhraseBans(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
  
    Dim tmpBuf As String ' temporary output buffer
  
    If (Len(msgData) > 0) Then
        If (LCase$(msgData) = "on") Then
            Call WriteINI("Other", "Phrasebans", "Y")
            
            Phrasebans = True
            
            tmpBuf = "Phrasebans activated."
        Else
            Call WriteINI("Other", "Phrasebans", "N")
            
            Phrasebans = False
            
            tmpBuf = "Phrasebans deactivated."
        End If
    Else
        If (Phrasebans = True) Then
            tmpBuf = "Phrasebans are enabled."
        Else
            tmpBuf = "Phrasebans are disabled."
        End If
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnPhraseBans

' handle cbans command
Private Function OnCBans(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer

    ' on/off/status
    u = msgData
    
    Select Case LCase$(u)
        Case "on"
            tmpBuf = "ClientBans enabled."
            BotVars.ClientBans = True
            WriteINI "Other", "ClientBansOn", "Y"
            
        Case "off"
            tmpBuf = "ClientBans disabled."
            BotVars.ClientBans = False
            WriteINI "Other", "ClientBansOn", "N"
            
        Case "status"
            tmpBuf = "ClientBans are currently " & IIf(BotVars.ClientBans, "enabled.", "disabled.")
    End Select
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnCBans

' handle mimic command
Private Function OnMimic(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer

    u = msgData
    
    If (Len(u) > 0) Then
        Mimic = LCase$(u)
        
        tmpBuf = "Mimicking [ " & u & " ]"
    Else
        tmpBuf = "Mimic who?"
    End If
  
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnMimic

' handle nomimic command
Private Function OnNoMimic(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    Mimic = vbNullString
    
    tmpBuf = "Mimic off."

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnNoMimic

' handle setpmsg command
Private Function OnSetPMsg(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer

    u = msgData
    
    ProtectMsg = u
    
    Call WriteINI("Other", "ProtectMsg", u)
    
    tmpBuf = "Channel protection message set."
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSetPMsg

' handle phrases command
Private Function OnPhrases(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf() As String ' temporary output buffer
    Dim tmpCount As Integer
    Dim response As String
    Dim i        As Integer
    Dim found    As Integer
    
    ReDim Preserve tmpBuf(tmpCount)

    tmpBuf(tmpCount) = "Phraseban(s): "
    
    For i = LBound(Phrases) To UBound(Phrases)
        If ((Phrases(i) <> " ") And (Phrases(i) <> vbNullString)) Then
            tmpBuf(tmpCount) = tmpBuf(tmpCount) & ", " & Phrases(i)
            
            If (Len(tmpBuf(tmpCount)) > 89) Then
                ReDim Preserve tmpBuf(tmpCount + 1)
                
                tmpBuf(tmpCount + 1) = "Phraseban(s): "
            
                tmpBuf(tmpCount) = Replace(tmpBuf(tmpCount), ", ", " ") & " [more]"
                
                tmpCount = (tmpCount + 1)
            End If
            
            found = (found + 1)
        End If
    Next i
    
    If (found > 0) Then
        tmpBuf(tmpCount) = Replace(tmpBuf(tmpCount), ", ", " ")
    Else
        tmpBuf(0) = "There are no phrasebans."
    End If
    
    ' return message
    cmdRet() = tmpBuf()
End Function ' end function OnPhrases

' handle addphrase command
Private Function OnAddPhrase(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim f      As Integer
    Dim c      As Integer
    Dim tmpBuf As String ' temporary output buffer
    Dim u      As String
    Dim i      As Integer
    
    ' grab free file handle
    f = FreeFile
    
    u = msgData
    
    For i = LBound(Phrases) To UBound(Phrases)
        If (StrComp(u, Phrases(i), vbTextCompare) = 0) Then
            Exit For
        End If
    Next i

    If (i > (UBound(Phrases))) Then
        If ((Phrases(UBound(Phrases)) <> vbNullString) Or _
            (Phrases(UBound(Phrases)) <> " ")) Then
            
            ReDim Preserve Phrases(0 To UBound(Phrases) + 1)
        End If
        
        Phrases(UBound(Phrases)) = u
        
        Open GetFilePath("phrasebans.txt") For Output As #f
            For c = LBound(Phrases) To UBound(Phrases)
                If (Len(Phrases(c)) > 0) Then
                    Print #f, Phrases(c)
                End If
            Next c
        Close #f
        
        tmpBuf = "Phraseban " & Chr(34) & u & Chr(34) & " added."
    Else
        tmpBuf = "That phrase is already banned."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnAddPhrase

' handle delphrase command
Private Function OnDelPhrase(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim f      As Integer
    Dim u      As String
    Dim Y      As String
    Dim tmpBuf As String ' temporary output buffer
    Dim c      As Integer
    
    u = msgData
    
    f = FreeFile
    
    Open GetFilePath("phrasebans.txt") For Output As #f
        Y = vbNullString
    
        For c = LBound(Phrases) To UBound(Phrases)
            If (StrComp(Phrases(c), LCase$(u), vbTextCompare) <> 0) Then
                Print #f, Phrases(c)
            Else
                Y = "x"
            End If
        Next c
    Close #f
    
    ReDim Phrases(0)
    
    Call frmChat.LoadArray(LOAD_PHRASES, Phrases())
    
    If (Len(Y) > 0) Then
        tmpBuf = "Phrase " & Chr(34) & u & Chr(34) & " deleted."
    Else
        tmpBuf = "That phrase is not banned."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnDelPhrase

' handle tagban command
Private Function OnTagBan(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim f      As Integer
    Dim tmpBuf As String ' temporary output buffer
    Dim u      As String
    
    ' grab free file handle
    f = FreeFile
    
    u = msgData
    
    If (Len(u) > 0) Then
        If (Len(GetTagbans(u)) > 1) Then
            tmpBuf = "That tag is covered by an existing tagban."
        Else
            Dim saCmdRet() As String
            
            ' declare index zero of array
            ReDim Preserve saCmdRet(0)
        
            If ((InStr(1, u, "*", vbTextCompare) = 0) And (Len(u) > 4)) Then
                Call OnShitAdd(Username, dbAccess, msgData, InBot, saCmdRet())
            End If
            
            If (Dir$(GetFilePath("tagbans.txt")) = vbNullString) Then
                Open (GetFilePath("tagbans.txt")) For Output As #f
                    ' ...
                Close #f
            End If
            
            Open (GetFilePath("tagbans.txt")) For Append As #f
                Print #f, u & vbCrLf
            Close #f
            
            If (InStr(u, " ") > 0) Then
                Call WildCardBan(u, Mid$(u, InStr(u, " ")), 1)
            Else
                Call WildCardBan(u, "Tagban: " & u, 1)
            End If
            
            tmpBuf = "Added tag " & Chr(34) & u & Chr(34) & " to the tagban list."
        End If
    Else
        tmpBuf = "What tag would you like to add?"
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnTagBan

' handle fadd command
Private Function OnFAdd(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer
    
    u = msgData
    
    If (Len(u) > 0) Then
        Call AddQ("/f a " & u, 1)
        
        tmpBuf = "Added user " & Chr(34) & u & Chr(34) & " to this account's friends list."
    Else
        tmpBuf = "Who do you want to add?"
    End If
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnFAdd

' handle frem command
Private Function OnFRem(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer
    
    u = msgData
    
    If (Len(u) > 0) Then
        Call AddQ("/f r " & u, 1)
        
        tmpBuf = "Removed user " & Chr(34) & u & Chr(34) & " from this account's friends list."
    Else
        tmpBuf = "Who do you want to remove?"
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnFRem

' handle safelist command
Private Function OnSafeList(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf() As String ' temporary output buffer
    Dim i        As Integer
    Dim tmpCount As Integer
    
    ReDim Preserve tmpBuf(tmpCount)

    If (colSafelist.Count = 0) Then
        tmpBuf(tmpCount) = "There are no safelisted users or tags."
    Else
        tmpBuf(tmpCount) = "Tags/users found: "

        For i = 1 To colSafelist.Count
            Debug.Print colSafelist.Item(i).Name
            
            tmpBuf(tmpCount) = tmpBuf(tmpCount) & _
                ReversePrepareCheck(colSafelist.Item(i).Name)
            
            If (i < colSafelist.Count) Then
                tmpBuf(tmpCount) = tmpBuf(tmpCount) & ", "
            End If
            
            If (Len(tmpBuf(tmpCount)) > 70) Then
                If (i < colSafelist.Count) Then
                    ReDim Preserve tmpBuf(tmpCount + 1)
                    
                    tmpBuf(tmpCount + 1) = "Tags/users found: "
                
                    tmpBuf(tmpCount) = tmpBuf(tmpCount) & " [more]"
                    
                    tmpCount = (tmpCount + 1)
                End If
            End If
        Next i
    End If
    
    ' return message
    cmdRet() = tmpBuf()
End Function ' end function OnSafeList

' handle safeadd command
Private Function OnSafeAdd(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    Dim u      As String
    
    u = msgData
        
    tmpBuf = AddToSafelist(u, Username)
    
    If (LenB(tmpBuf) = 0) Then
        tmpBuf = "Added tag/user " & Chr(34) & u & Chr(34) & " to the safelist."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSafeAdd

' handle exile command
Private Function OnExile(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim saCmdRet() As String
    Dim ibCmdRet() As String
    Dim u          As String
    Dim Y          As String
    
    ReDim Preserve saCmdRet(0)
    ReDim Preserve ibCmdRet(0)

    u = msgData
    
    Call OnShitAdd(Username, dbAccess, u, InBot, saCmdRet())
    Call OnIPBan(Username, dbAccess, u, InBot, ibCmdRet())
End Function ' end function OnExile

' handle unexile command
Private Function OnUnExile(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u          As String
    Dim sdCmdRet() As String
    Dim uiCmdRet() As String
    
    ' declare index zero of array
    ReDim Preserve sdCmdRet(0)
    ReDim Preserve uiCmdRet(0)

    u = msgData
    
    Call OnShitDel(Username, dbAccess, u, InBot, sdCmdRet())
    Call OnUnignore(Username, dbAccess, u, InBot, uiCmdRet())
End Function ' end function OnUnExile

' TO DO:
' handle shitlist command
Private Function OnShitList(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim f          As Integer
    Dim strArray() As String
    Dim Y          As String
    Dim tmpBuf     As String ' temporary output buffer
    Dim i          As Integer
    Dim response   As String

    Y = GetFilePath("autobans.txt")
        
    If LenB(Dir$(Y)) = 0 Then
        tmpBuf = "No shitlist found."
    End If
    
    Open (Y) For Input As #f
    
        If (LOF(f) < 2) Then
            tmpBuf = "There are no shitlisted users."
        End If
        
        Do
            i = i + 1
            Line Input #f, response
            
            ReDim Preserve strArray(0 To i)
            
            If ((response <> vbNullString) And (Len(response) >= 2)) Then
                If (InStr(response, " ")) Then
                    strArray(i) = Mid$(response, 1, InStr(response, " ") - 1)
                Else
                    strArray(i) = response
                End If
            Else
                i = i - 1
            End If
        Loop While Not EOF(f)
        
    Close #f
    
    tmpBuf = "Tags/users found: "
    
    For i = (LBound(strArray) + 1) To UBound(strArray)
        tmpBuf = tmpBuf & strArray(i)
        
        If (i <> UBound(strArray)) Then
            tmpBuf = tmpBuf & ", "
        End If
        
        If Len(tmpBuf) > 70 Then
            If (i <> UBound(strArray)) Then
                tmpBuf = tmpBuf & " [more]"
            End If
            
            'If WhisperCmds And Not InBot Then
            '    If Dii Then AddQ "/w *" & Username & Space(1) & tmpBuf Else AddQ "/w " & Username & Space(1) & tmpBuf
            'ElseIf InBot = True And Not PublicOutput Then
            '    frmChat.AddChat RTBColors.ConsoleText, tmpBuf
            'Else
            '    AddQ tmpBuf
            'End If
            
            tmpBuf = "Tags/users found: "
        End If
    Next i
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnShitList

' TO DO:
' handle tagbans command
Private Function OnTagBans(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf     As String  ' temporary output buffer
    Dim tmpCount   As Integer
    Dim strArray() As String
    
    If (Dir$(GetFilePath("tagbans.txt")) = vbNullString) Then
        tmpBuf = "No tagbans list found."
    Else
        Dim f As Integer
    
        f = FreeFile
    
        Open (GetFilePath("tagbans.txt")) For Input As #f
            If (LOF(f) < 2) Then
                tmpBuf = "No users are tagbanned."
            Else
                Dim response As String
                Dim i        As Integer
                
                Do
                    i = (i + 1)
                    
                    Input #f, response
                    
                    ReDim Preserve strArray(0 To i)
                    
                    If ((response <> vbNullString) And (Len(response) >= 2)) Then
                        strArray(i) = response
                    Else
                        i = (i - 1)
                    End If
                    
                Loop Until EOF(f)
            End If
        
        Close #f
        
        tmpBuf = "Tagbans found: "
        
        For i = (LBound(strArray) + 1) To UBound(strArray)
            tmpBuf = tmpBuf & strArray(i) & ", "
            
            If (Len(tmpBuf) > 80) Then
                tmpBuf = Left$(tmpBuf, Len(tmpBuf) - 2)
                
                tmpBuf = tmpBuf & " [more]"
                
                'If ((WhisperCmds) And (Not (InBot))) Then
                '    If (Dii) Then
                '        AddQ "/w *" & Username & Space(1) & tmpBuf
                '    Else
                '        AddQ "/w " & Username & Space(1) & tmpBuf
                '    End If
                'ElseIf ((InBot = True) And (Not (PublicOutput))) Then
                '    frmChat.AddChat RTBColors.ConsoleText, tmpBuf
                'Else
                '    AddQ tmpBuf
                'End If
                
                tmpBuf = "Tagbans found: "
            End If
        Next i
        
        tmpBuf = Left$(tmpBuf, Len(tmpBuf) - 2)
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnTagBans

' handle shitadd command
Private Function OnShitAdd(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim gAcc   As udtGetAccessResponse
    
    Dim u      As String
    Dim tmpBuf As String
    Dim f      As Integer
    Dim Y      As String
    
    f = FreeFile
    
    u = msgData

    If LenB(GetShitlist(u)) > 0 Then
        tmpBuf = "That user is already shitlisted."
    Else
        gAcc = GetAccess(u)
    
        If (InStr(1, u, "*", vbBinaryCompare) > 0) Then
            Dim tbBuf() As String
        
            Call OnTagBan(Username, gAcc, msgData, InBot, tbBuf())
        Else
            If (dbAccess.Access <= gAcc.Access) Then
                tmpBuf = "You do not have access to do that."
            ElseIf ((dbAccess.Access < 100) And (InStr(gAcc.Access, "A") > 0)) Then
                tmpBuf = "You do not have access to do that."
            Else
                Y = GetFilePath("autobans.txt")
            
                If (Dir$(Y) = vbNullString) Then
                    Open (Y) For Output As #f
                        ' ...
                    Close #f
                End If
            
                Open (Y) For Append As #f
                    Print #f, u
                Close #f
            
                If ((MyFlags = 2) Or (MyFlags = 18)) Then
                    Call AddQ("/ban " & IIf(Dii, "*", "") & u, 1)
                End If
                
                tmpBuf = "Added " & u & " to the shitlist."
            End If
        End If
    End If
   
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnShitAdd

' handle dnd command
Private Function OnDND(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim DNDMsg As String
    
    If (Len(msgData) = 0) Then
        AddQ "/dnd", 1
    Else
        DNDMsg = msgData
    
        AddQ "/dnd " & DNDMsg, 1
    End If
End Function ' end function OnDND

' handle bancount command
Private Function OnBanCount(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    If (BanCount = 0) Then
        tmpBuf = "No users have been banned since I joined this channel."
    Else
        tmpBuf = "Since I joined this channel, " & BanCount & " user(s) have been banned."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnBanCount

' handle tagcheck command
Private Function OnTagCheck(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim Y      As String
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer
    
    u = msgData
    
    Y = GetTagbans(u)
    
    If (Len(Y) < 2) Then
        tmpBuf = "That user matches no tagbans."
    Else
        tmpBuf = "That user matches the following tagban(s): " & Y
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnTagCheck

' handle slcheck command
Private Function OnSLCheck(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim gAcc   As udtGetAccessResponse
    
    Dim Y      As String
    Dim Track  As Long
    Dim tmpBuf As String ' temporary output buffer

    Y = msgData
            
    If (LenB(Y) > 0) Then
        tmpBuf = "That user "
        
        gAcc = GetAccess(Y)
        
        If (InStr(gAcc.Flags, "B") > 0) Then
            tmpBuf = tmpBuf & "has 'B' in their flags"
            Track = 1
        End If
        
        If (LenB(GetShitlist(Y))) Then
            If (Track = 1) Then
                tmpBuf = tmpBuf & " and "
            End If
            
            tmpBuf = tmpBuf & "is on the bot's shitlist"
            
            Track = 2
        End If
        
        If (Track > 0) Then
            tmpBuf = tmpBuf & "."
        Else
            tmpBuf = "That user is not shitlisted and does not have 'B' in their flags."
        End If
    Else
        tmpBuf = "Please specify a username to check."
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSLCheck

' handle readfile command
Private Function OnReadFile(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u        As String
    Dim tmpBuf() As String ' temporary output buffer
    Dim tmpCount As Integer
    
    ' redefine array size
    ReDim Preserve tmpBuf(tmpCount)
    
    u = msgData
    
    If (Len(u) > 0) Then
        If (InStr(1, u, "..", vbBinaryCompare) > 0) Then
            tmpBuf(tmpCount) = "Files may only be read from program directory."
        ElseIf (InStr(1, u, ".ini", vbTextCompare) > 0) Then
            tmpBuf(tmpCount) = "Configuration files may not be read."
        Else
            Dim Y As String  ' ...
            Dim f As Integer ' ...
        
            ' grab a file number
            f = FreeFile
        
            If (InStr(u, ".") > 0) Then
                Y = Left$(u, InStr(u, ".") - 1)
            Else
                Y = u
            End If
            
            ' get absolute file path
            u = App.Path & "\" & u
                    
            Select Case UCase$(Y)
                Case "CON", "PRN", "AUX", "CLOCK$", "NUL", "COM1", "COM2", "COM3", _
                    "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", _
                    "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
                    
                    tmpBuf(tmpCount) = "You cannot read that file."
            End Select
            
            If (Dir$(u) = vbNullString) Then
                tmpBuf(tmpCount) = "File does not exist."
            Else
                ' store line in buffer
                tmpBuf(tmpCount) = "Contents of file " & msgData & ":"
                
                ' increment counter
                tmpCount = (tmpCount + 1)
            
                ' open file
                Open u For Input As #f
                    ' read until end-of-line
                    Do While (EOF(f) = False)
                        Dim tmp As String ' ...
                        
                        ' read line into tmp
                        Input #f, tmp
                        
                        If (tmp <> vbNullString) Then
                            ' redefine array size
                            ReDim Preserve tmpBuf(tmpCount)
                        
                            ' store line in buffer
                            tmpBuf(tmpCount) = tmp
                            
                            ' increment counter
                            tmpCount = (tmpCount + 1)
                        End If
                    Loop
                Close #f
                
                ' redefine array size
                ReDim Preserve tmpBuf(tmpCount)
                
                ' store line in buffer
                tmpBuf(tmpCount) = "End of File."
            End If
        End If
    Else
        tmpBuf(tmpCount) = "Error reading file."
    End If
    
    ' return message
    cmdRet() = tmpBuf()
End Function ' end function OnReadFile

' TO DO:
' handle greet command
Private Function OnGreet(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim strArray() As String
    Dim tmpBuf     As String ' temporary output buffer
    
    strArray() = Split(msgData, " ", 3)
        
    If (UBound(strArray) > 0) Then
        Select Case LCase$(strArray(1))
            Case "on"
                BotVars.UseGreet = True
                tmpBuf = "Greet messages enabled."
                WriteINI "Other", "UseGreets", "Y"
            
            Case "off"
                BotVars.UseGreet = False
                tmpBuf = "Greet messages disabled."
                WriteINI "Other", "UseGreets", "N"
                
            Case "whisper"
                If UBound(strArray) > 1 Then
                    Select Case LCase$(strArray(2))
                        Case "on"
                            BotVars.WhisperGreet = True
                            tmpBuf = "Greet messages will now be whispered."
                            WriteINI "Other", "WhisperGreet", "Y"
                            
                        Case "off"
                            BotVars.WhisperGreet = False
                            tmpBuf = "Greet messages will no longer be whispered."
                            WriteINI "Other", "WhisperGreet", "N"
                            
                    End Select
                End If

            Case Else
                If InStr(1, msgData, "/squelch", vbTextCompare) > 0 Or _
                    InStr(1, msgData, "/ban ", vbTextCompare) > 0 Or _
                        InStr(1, msgData, "/ignore", vbTextCompare) > 0 Or _
                            InStr(1, msgData, "/des", vbTextCompare) > 0 Or _
                                InStr(1, msgData, "/re", vbTextCompare) > 0 Then
                                
                    tmpBuf = "One or more invalid terms are present. Greet message not set."
                Else
                    tmpBuf = "Greet message set."
                    BotVars.GreetMsg = Right(msgData, Len(msgData) - 7)
                    WriteINI "Other", "GreetMsg", Right(msgData, Len(msgData) - 7)
                End If
        
        End Select
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnGreet

' handle allseen command
Private Function OnAllSeen(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf() As String ' temporary output buffer
    Dim tmpCount As Integer
    Dim i        As Integer

    ' redefine array size
    ReDim Preserve tmpBuf(tmpCount)

    ' prefix message with "Last 15 users seen"
    tmpBuf(tmpCount) = "Last 15 users seen: "
    
    ' were there any users seen?
    If (colLastSeen.Count = 0) Then
        tmpBuf(tmpCount) = tmpBuf(tmpCount) & "(list is empty)"
    Else
        For i = 1 To colLastSeen.Count
            ' append user to list
            tmpBuf(tmpCount) = tmpBuf(tmpCount) & _
                colLastSeen.Item(i) & ", "
            
            If (Len(tmpBuf(tmpCount)) > 90) Then
                If (i < colLastSeen.Count) Then
                    ' redefine array size
                    ReDim Preserve tmpBuf(tmpCount + 1)
                    
                    ' clear new array index
                    tmpBuf(tmpCount + 1) = vbNullString
                    
                    ' remove ending comma from index
                    tmpBuf(tmpCount) = Mid$(tmpBuf(tmpCount), 1, _
                        Len(tmpBuf(tmpCount)) - Len(", "))
                
                    ' postfix [more] to end of entry
                    tmpBuf(tmpCount) = tmpBuf(tmpCount) & " [more]"
                    
                    ' increment loop counter
                    tmpCount = (tmpCount + 1)
                End If
            End If
        Next i
        
        ' check for ending comma
        If (Right$(tmpBuf(tmpCount), 2) = ", ") Then
            ' remove ending comma from index
            tmpBuf(tmpCount) = Mid$(tmpBuf(tmpCount), 1, _
                Len(tmpBuf(tmpCount)) - Len(", "))
        End If
    End If
    
    ' return message
    cmdRet() = tmpBuf()
End Function ' end function OnAllSeen

' handle ban command
Private Function OnBan(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean

    Dim u        As String
    Dim tmpBuf   As String ' temporary output buffer
    Dim banMsg   As String
    Dim Y        As String
    Dim i        As Integer

    If ((MyFlags <> 2) And (MyFlags <> 18)) Then
        If (InBot) Then
            tmpBuf = "You are not a channel operator."
        End If
    End If

    u = msgData
    
    i = InStr(1, u, " ")
    
    If (i > 0) Then
        banMsg = Mid$(u, i + 1)
        u = Left$(u, i - 1)
    End If
    
    If (InStr(1, u, "*", vbTextCompare) > 0) Then
        WildCardBan u, banMsg, 1
    Else
        If (banMsg <> vbNullString) Then
            Y = Ban(u & IIf(Len(banMsg) > 0, " " & banMsg, vbNullString), dbAccess.Access)
        Else
            Y = Ban(u & IIf(Len(banMsg) > 0, " " & banMsg, vbNullString), dbAccess.Access)
        End If
    End If
    
    If (Len(Y) > 2) Then
        tmpBuf = Y
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnBan

' handle unban command
Private Function OnUnBan(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer
    
    u = msgData
    
    If (bFlood) Then
        If (floodCap < 45) Then
            floodCap = (floodCap + 15)
            
            Call bnetSend("/unban " & u)
        End If
    End If
    
    If (InStr(1, msgData, "*", vbTextCompare) <> 0) Then
        Call WildCardBan(u, vbNullString, 2)
    End If
    
    If Dii = True Then
        If (Not (Mid$(u, 1, 1) = "*")) Then
            u = "*" & u
        End If
    End If
    
    tmpBuf = "/unban " & u

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnUnBan

' handle kick command
Private Function OnKick(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u      As String
    Dim i      As Integer
    Dim banMsg As String
    Dim tmpBuf As String ' temporary output buffer
    Dim Y      As String
    
    If ((MyFlags <> 2) And (MyFlags <> 18)) Then
       If InBot Then
           tmpBuf = "You are not a channel operator."
       End If
    End If
    
    u = msgData
    
    i = InStr(1, u, " ", vbTextCompare)
    
    If (i > 0) Then
        banMsg = Mid$(u, i + 1)
        
        u = Left$(u, i - 1)
    End If
    
    If (InStr(1, u, "*", vbTextCompare) > 0) Then
        If (dbAccess.Access > 99) Then
            Call WildCardBan(u, banMsg, 0)
        Else
            Call WildCardBan(u, banMsg, 0)
        End If
    End If
    
    Y = Ban(u & IIf(Len(banMsg) > 0, " " & banMsg, vbNullString), _
        dbAccess.Access, 1)
    
    If (Len(Y) > 1) Then
        tmpBuf = Y
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnKick

' handle lastwhisper command
Private Function OnLastWhisper(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    If (LastWhisper <> vbNullString) Then
        tmpBuf = "The last whisper to this bot was from: " & LastWhisper
    Else
        tmpBuf = "The bot has not been whispered since it logged on."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnLastWhisper

' handle say command
Private Function OnSay(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean

    Dim tmpBuf  As String ' temporary output buffer
    Dim tmpSend As String ' ...
    
    If (Len(msgData) > 0) Then
        If (dbAccess.Access >= GetAccessINIValue("say70", 70)) Then
            If (dbAccess.Access >= GetAccessINIValue("say90", 90)) Then
                tmpSend = msgData
            Else
                tmpSend = Replace(msgData, "/", "")
            End If
        Else
            tmpSend = Username & " says: " & msgData
        End If
        
        Call AddQ(tmpSend)
    Else
        tmpBuf = "Say what?"
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnSay

' handle expand command
Private Function OnExpand(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf  As String ' temporary output buffer
    Dim tmpSend As String

    If (Len(msgData) > 0) Then
        tmpSend = Expand(msgData)
        
        If (Len(tmpSend) > 220) Then
            tmpSend = Mid$(tmpSend, 1, 220)
        End If
        
        Call AddQ(tmpSend, 1)
    Else
        tmpBuf = "Expand what?"
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnExpand

' handle detail command
Private Function OnDetail(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    tmpBuf = GetDBDetail(msgData)
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnDetail

' handle info command
Private Function OnInfo(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim user      As String
    Dim userIndex As Integer
    Dim tmpBuf()  As String ' temporary output buffer

    user = msgData
    
    userIndex = UsernameToIndex(user)
    
    If (userIndex > 0) Then
        ReDim Preserve tmpBuf(0 To 1)
    
        With colUsersInChannel.Item(userIndex)
            tmpBuf(0) = "User " & .Username & " is logged on using " & _
                ProductCodeToFullName(.Product)
            
            If ((.Flags) And (&H2) = &H2) Then
                tmpBuf(0) = tmpBuf(0) & " with ops, and a ping time of " & .Ping & "ms."
            Else
                tmpBuf(0) = tmpBuf(0) & " with a ping time of " & .Ping & "ms."
            End If
            
            tmpBuf(1) = "He/she has been present in the channel for " & _
                ConvertTime(.TimeInChannel(), 1) & "."
        End With
    Else
        tmpBuf(0) = "No such user is present."
    End If
    
    ' return message
    cmdRet() = tmpBuf()
End Function ' end function OnInfo

' handle shout command
Private Function OnShout(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean

    Dim tmpBuf  As String ' temporary output buffer
    Dim tmpSend As String

    If (Len(msgData) > 0) Then
        If (dbAccess.Access > 69) Then
            If (dbAccess.Access > 89) Then
                tmpSend = msgData
            Else
                tmpSend = Replace(msgData, "/", vbNullString, 1)
            End If
        Else
            tmpSend = Username & " shouts: " & msgData
        End If
        
        Call AddQ(UCase$(tmpSend))
    Else
        tmpBuf = "Shout what?"
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnShout

' handle voteban command
Private Function OnVoteBan(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    Dim user   As String
    
    user = msgData
    
    If (VoteDuration = 1) Then
        Call Voting(BVT_VOTE_START, BVT_VOTE_BAN, user)
        
        VoteDuration = 30
        
        tmpBuf = "30-second VoteBan vote started. Type YES to ban " & user & ", NO to acquit him/her."
    Else
        tmpBuf = "A vote is currently in progress."
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnVoteBan

' handle votekick command
Private Function OnVoteKick(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean

    Dim tmpBuf   As String ' temporary output buffer
    Dim user     As String
    
    user = msgData
    
    If (VoteDuration = -1) Then
        Call Voting(BVT_VOTE_START, BVT_VOTE_KICK, user)
        
        VoteDuration = 30
        
        VoteInitiator = dbAccess
        
        tmpBuf = "30-second VoteKick vote started. Type YES to kick " & user & ", NO to acquit him/her."
    Else
        tmpBuf = "A vote is currently in progress."
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnVoteKick

' handle vote command
Private Function OnVote(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
 
    Dim tmpBuf      As String ' temporary output buffer
    Dim tmpDuration As Long
    
    If (Len(msgData) > 0) Then
        If (VoteDuration = -1) Then
            ' ensure that tmpDuration is an integer
            tmpDuration = Val(msgData)
        
            ' check for proper duration time and call for vote
            If ((tmpDuration > 0) And (tmpDuration <= 32000)) Then
                ' set vote duration
                VoteDuration = tmpDuration
                
                ' set vote initiator
                VoteInitiator = dbAccess
                
                ' execute vote
                Call Voting(BVT_VOTE_START, BVT_VOTE_STD)
                
                tmpBuf = "Vote initiated. Type YES or NO to vote; your vote will be counted only once."
            Else
                ' duration entered is either negative, is too large, or is a string
                tmpBuf = "Please enter a number of seconds for your vote to last."
            End If
        Else
            tmpBuf = "A vote is currently in progress."
        End If
    Else
        ' duration not entered
        tmpBuf = "Please enter a number of seconds for your vote to last."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnVote

' handle tally command
Private Function OnTally(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
     
    Dim tmpBuf As String ' temporary output buffer
     
    If (VoteDuration > 0) Then
        tmpBuf = Voting(BVT_VOTE_TALLY)
    Else
        tmpBuf = "No vote is currently in progress."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnTally

' handle cancel command
Private Function OnCancel(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    If (VoteDuration > 0) Then
        tmpBuf = Voting(BVT_VOTE_END, BVT_VOTE_CANCEL)
    Else
        tmpBuf = "No vote in progress."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnCancel

' handle back command
Private Function OnBack(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    Dim hWndWA As Long
    
    If (AwayMsg <> vbNullString) Then
        Call AddQ("/away", 1)
        
        If (Not (InBot)) Then
            ' alert users of status change
            Call AddQ("/me is back from " & AwayMsg & ".")
            
            ' set away message
            AwayMsg = vbNullString
        End If
    Else
        If (Not (BotVars.DisableMP3Commands)) Then
            If (iTunesReady) Then
                iTunesBack
                
                tmpBuf = "Skipped backwards."
            Else
                hWndWA = GetWinamphWnd()
                
                If (hWndWA = 0) Then
                   tmpBuf = "Winamp is not loaded."
                End If
                
                Call SendMessage(hWndWA, WM_COMMAND, WA_PREVTRACK, 0)
                
                tmpBuf = "Skipped backwards."
            End If
        End If
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnBack

' handle uptime command
Private Function OnUptime(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    tmpBuf = "System uptime " & ConvertTime(GetUptimeMS) & _
        ", connection uptime " & ConvertTime(uTicks) & "."
        
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnUptime

' handle away command
Private Function OnAway(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    If (Len(AwayMsg) > 0) Then
        ' send away command to battle.net
        Call AddQ("/away")
        
        ' alert users of status change
        If (Not (InBot)) Then
            Call AddQ("/me is back from (" & AwayMsg & ")")
        End If
        
        ' set away message
        AwayMsg = vbNullString
    Else
        If (Len(msgData) > 0) Then
            ' set away message
            AwayMsg = msgData
            
            ' send away command to battle.net
            Call AddQ("/away " & AwayMsg)
            
            ' alert users of status change
            If (Not (InBot)) Then
                Call AddQ("/me is away (" & AwayMsg & ")")
            End If
        Else
            ' set away message
            AwayMsg = " - "
        
            ' send away command to battle.net
            Call AddQ("/away")
            
            ' alert users of status change
            If (Not (InBot)) Then
                Call AddQ("/me is away.")
            End If
        End If
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnAway

' handle MP3 command
Private Function OnMP3(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim WindowTitle As String
    Dim tmpBuf      As String ' temporary output buffer
    
    WindowTitle = GetCurrentSongTitle(True)

    If (WindowTitle = vbNullString) Then
        tmpBuf = "Winamp is not loaded."
    Else
        tmpBuf = "Current MP3: " & WindowTitle
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnMP3

' handle deldef command
Private Function OnDelDef(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
'    On Error GoTo error_deldef
'
'    Dim u      As String
'    Dim tmpBuf As String ' temporary output buffer
'
'    u = Mid$(msgData, 9)
'
'    If (Len(u) > 0) Then
'        WriteINI "Def", u, "%deleted%", "definitions.ini"
'
'        tmpBuf = "That definition has been erased."
'    Else
'
'error_deldef:
'        tmpBuf = "There was an error removing that definition."
'    End If
'
'    ' return message
'    cmdRet(0) = tmpBuf
End Function ' end function OnDelDef

' handle define command
Private Function OnDefine(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
'    On Error GoTo sendyz
'
'    Dim response As String
'    Dim u        As String
'    Dim tmpBuf   As String ' temporary output buffer
'    Dim Track    As Long
'
'    If (Dir$(GetFilePath("definitions.ini")) = vbNullString) Then
'        tmpBuf = "No definition list found. Please use " & _
'            "'.newdef term|definition' to make one."
'    End If
'
'    If Left$(msgData, 8) = "define" Then
'        Track = 8
'    Else
'        Track = 5
'    End If
'
'    u = LCase$(Trim(Mid$(msgData, Track)))
'
'    response = ReadINI("Def", u, "definitions.ini")
'
'    If ((response = vbNullString) Or _
'        (StrComp(response, "%deleted%"))) = 0 Then
'
'        tmpBuf = "No definition on file for " & u & "."
'    Else
'        tmpBuf = "[" & u & "]: " & response
'    End If
'
'sendyz:
'    tmpBuf = "Define what?"
'
'    ' return message
'    cmdRet(0) = tmpBuf
End Function ' end function OnDefine

' handle newdef command
Private Function OnNewDef(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
'    On Error GoTo sendi2
'
'    Dim Track  As Long
'    Dim tmpBuf As String ' temporary output buffer
'    Dim u      As String
'    Dim z      As String
'
'    u = Right(msgData, Len(msgData) - 8)
'
'    Track = InStr(1, u, "|", vbTextCompare)
'
'    z = Right(u, Len(u) - Track)
'    u = Left$(u, Len(u) - Len(z) - 1)
'
'    If (z = "") Then
'        tmpBuf = "You need to specify a definition."
'    End If
'
'    WriteINI "Def", u, z, "definitions.ini"
'
'    tmpBuf = "Added a definition for """ & u & """."
'
'sendi2:
'    tmpBuf = "Error: Please format your definitions correctly. (.newdef term|definition)"
'
'    ' return message
'    cmdRet(0) = tmpBuf
End Function ' end function OnNewDef

' handle ping command
Private Function OnPing(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf  As String ' temporary output buffer
    Dim latency As Long
    Dim user    As String
    
    user = msgData
    
    If (Len(user) > 0) Then
        latency = GetPing(user)
        
        If (latency < -1) Then
            tmpBuf = "I can't see " & user & " in the channel."
        Else
            tmpBuf = user & "'s ping at login was " & latency & "ms."
        End If
    Else
        tmpBuf = "Ping who?"
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnPing

' handle addquote command
Private Function OnAddQuote(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim f      As Integer
    Dim u      As String
    Dim Y      As String
    Dim tmpBuf As String ' temporary output buffer
    
    f = FreeFile
    
    u = msgData
    
    If (Len(u) > 0) Then
        Y = Dir$(GetFilePath("quotes.txt"))
        
        If (LenB(Y) = 0) Then
            Open (Y) For Output As #f
                Print #f, u
            Close #f
        Else
            Open (Y) For Append As #f
                Print #f, u
            Close #f
        End If
            
        tmpBuf = "Quote added!"
    Else
        tmpBuf = "I need a quote to add."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnAddQuote

' handle owner command
Private Function OnOwner(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    If (LenB(BotVars.BotOwner) > 0) Then
        tmpBuf = "This bot's owner is " & BotVars.BotOwner & "."
    Else
        tmpBuf = "No owner is set."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnOwner

' handle ignore command
Private Function OnIgnore(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean

    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer
        
    u = msgData
    
    If (Len(u) > 0) Then
        If ((GetAccess(u).Access >= dbAccess.Access) Or _
            (InStr(GetAccess(u).Flags, "A"))) Then
            
            tmpBuf = "That user has equal or higher access."
        Else
            AddQ "/ignore " & IIf(Dii, "*", "") & u, 1
            
            tmpBuf = "Ignoring messages from " & Chr(34) & u & Chr(34) & "."
        End If
    Else
        tmpBuf = "Unignore who?"
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnIgnore

' handle quote command
Private Function OnQuote(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    tmpBuf = GetRandomQuote
    
    If (Len(tmpBuf) = 0) Then
        tmpBuf = "Error reading quotes, or no quote file exists."
    ElseIf (Len(tmpBuf) > 220) Then
        ' try one more time
        tmpBuf = GetRandomQuote
        
        If (Len(tmpBuf) > 220) Then
            'too long? too bad. truncate
            tmpBuf = Left$(tmpBuf, 220)
        End If
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnQuote

' handle unignore command
Private Function OnUnignore(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean

    Dim u      As String
    Dim tmpBuf As String ' temporary output buffer
    
    u = msgData
    
    If (Len(msgData) > 0) Then
        AddQ "/unignore " & IIf(Dii, "*", "") & u, 1
        
        tmpBuf = "Receiving messages from """ & u & """."
    Else
        tmpBuf = "Unignore who?"
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnUnignore

' handle cq command
Private Function OnCQ(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    While (colQueue.Count > 0)
        Call colQueue.Remove(1)
    Wend
    
    tmpBuf = "Queue cleared."

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnCQ

' handle scq command
Private Function OnSCQ(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    While (colQueue.Count > 0)
        Call colQueue.Remove(1)
    Wend

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnCQ

' handle time command
Private Function OnTime(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    tmpBuf = "The current time on this computer is " & Time & " on " & _
        Format(Date, "MM-dd-yyyy") & "."
            
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnTime

' handle getping command
Private Function OnGetPing(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf  As String ' temporary output buffer
    Dim latency As Long

    If (InBot) Then
        If (g_Online) Then
            ' grab current latency
            latency = GetPing(CurrentUsername)
        
            tmpBuf = "Your ping at login was " & latency & "ms."
        Else
            tmpBuf = "You are not connected."
        End If
    Else
        latency = GetPing(Username)
    
        If (latency > -2) Then
            tmpBuf = "Your ping at login was " & latency & "ms."
        End If
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnGetPing

' handle checkmail command
Private Function OnCheckMail(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim Track  As Long
    Dim tmpBuf As String ' temporary output buffer
    
    If (InBot) Then
        Track = GetMailCount(CurrentUsername)
    Else
        Track = GetMailCount(Username)
    End If
    
    If (Track > 0) Then
        tmpBuf = "You have " & Track & " new messages."
        
        If (InBot) Then
            tmpBuf = tmpBuf & " Type /getmail to retrieve them."
        Else
            tmpBuf = tmpBuf & " Type !inbox to retrieve them."
        End If
    Else
        tmpBuf = "You have no mail."
    End If
     
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnCheckMail

' handle getmail command
Private Function OnGetMail(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim Msg As udtMail
    
    Dim tmpBuf As String ' temporary output buffer
            
    If (InBot) Then
        Username = CurrentUsername
    End If
    
    If (GetMailCount(Username) > 0) Then
        Call GetMailMessage(Username, Msg)
        
        If (Len(RTrim(Msg.To)) > 0) Then
            tmpBuf = "msgData from " & RTrim(Msg.From) & ": " & RTrim(Msg.Message)
        End If
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnGetMail

' handle whoami command
Private Function OnWhoAmI(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean

    Dim tmpBuf As String ' temporary output buffer

    If (InBot) Then
        tmpBuf = "You are the bot console."
    
        If (g_Online) Then
            AddQ "/whoami"
        End If
    ElseIf (dbAccess.Access = 1000) Then
        tmpBuf = "You are the bot owner, " & Username & "."
    Else
        tmpBuf = "You have "
    
        If (dbAccess.Access > 0) Then
            tmpBuf = tmpBuf & dbAccess.Access & " access"
    
            If (dbAccess.Flags <> vbNullString) Then
                tmpBuf = tmpBuf & " and "
            End If
       End If
    
        If (dbAccess.Flags <> vbNullString) Then
            tmpBuf = tmpBuf & "flags " & dbAccess.Flags
        End If
    
        If (StrComp(tmpBuf, "You have ") = 0) Then
            tmpBuf = "You have no access or flags, " & Username & "."
        Else
            tmpBuf = tmpBuf & ", " & Username & "."
        End If
    End If

    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnWhoAmI

' TO DO:
' handle add command
Private Function OnAdd(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean

    ' ...
    Dim gAcc       As udtGetAccessResponse

    Dim strArray() As String  ' ...
    Dim i          As Integer ' ...
    Dim tmpBuf     As String  ' temporary output buffer
    Dim dbPath     As String  ' ...
    Dim user       As String  ' ...
    Dim rank       As Integer ' ...
    Dim Flags      As String  ' ...
    Dim found      As Boolean ' ...
    
    ' split message
    strArray() = Split(msgData, " ")
    
    If (UBound(strArray) > 0) Then
        ' grab username
        user = strArray(0)
        
        ' grab rank & flags
        If (StrictIsNumeric(strArray(1))) Then
            ' grab rank
            rank = strArray(1)
            
            ' grab flags
            If (UBound(strArray) = 2) Then
                Flags = strArray(2)
            End If
        Else
            ' grab flags
            Flags = strArray(1)
        End If
        
        ' convert flags to uppercase
        Flags = UCase$(Flags)
        
        ' grab user access
        gAcc = GetAccess(user)
        
        ' is rank valid?
        If (rank < 0) Then
            tmpBuf = "Invalid rank."
            
        ' is rank higher than user's rank?
        ElseIf (rank >= dbAccess.Access) Then
            tmpBuf = "You do not have sufficient access to perform that command."
            
        ' can we modify specified user?
        ElseIf (gAcc.Access >= dbAccess.Access) Then
            tmpBuf = "You do not have sufficient access to perform that command."
        Else
            ' did we specify flags?
            If (Len(Flags) > 0) Then
                Dim currentCharacter As String ' ...
            
                For i = 1 To Len(Flags)
                    currentCharacter = Mid$(Flags, i, 1)
                
                    If ((currentCharacter <> "+") And (currentCharacter <> "-")) Then
                        Select Case (currentCharacter)
                            Case "A" ' administrator
                                If (dbAccess.Access <= 100) Then
                                    Exit For
                                End If
                                
                            Case "B" ' banned
                                If (dbAccess.Access < 70) Then
                                    Exit For
                                End If
                                
                            Case "D" ' designated
                                If (dbAccess.Access < 100) Then
                                    Exit For
                                End If
                            
                            Case "L" ' locked
                                If (dbAccess.Access < 70) Then
                                    Exit For
                                End If
                            
                            Case "S" ' safelisted
                                If (dbAccess.Access < 70) Then
                                    Exit For
                                End If
                                
                            Case "Z" ' tagbanned
                                If (dbAccess.Access < 70) Then
                                    Exit For
                                End If
                        End Select
                    End If
                Next i
                
                If (i < (Len(Flags) + 1)) Then
                    ' return message
                    cmdRet(0) = "You do not have sufficient access to perform that command."
                    
                    Exit Function
                Else
                    ' are we adding flags?
                    If (Left$(Flags, 1) = "+") Then
                        ' remove "+" prefix
                        Flags = Mid$(Flags, 2)
                    
                        ' check for special flags
                        If (InStr(1, Flags, "B", vbBinaryCompare) <> 0) Then
                            Call Ban(strArray(1) & " AutoBan", (AutoModSafelistValue - 1))
                        ElseIf (InStr(1, Flags, "S", vbBinaryCompare) <> 0) Then
                            Call AddToSafelist(strArray(1), Username)
                        ElseIf (InStr(1, Flags, "Z", vbBinaryCompare) <> 0) Then
                            Call WildCardBan(strArray(1), "Tagbanned", 1)
                        End If
                    
                        ' set user flags & check for duplicate entries
                        For i = 1 To Len(Flags)
                            currentCharacter = Mid$(Flags, i, 1)
                        
                            ' is flag valid (alphabetic)?
                            If (((Asc(currentCharacter) >= Asc("A")) And (Asc(currentCharacter) <= Asc("Z"))) Or _
                                ((Asc(currentCharacter) >= Asc("a")) And (Asc(currentCharacter) <= Asc("z")))) Then
                                
                                If (InStr(1, gAcc.Flags, currentCharacter, vbBinaryCompare) = 0) Then
                                    gAcc.Flags = gAcc.Flags & currentCharacter
                                End If
                            End If
                        Next i
                        
                    ' are we removing flags?
                    ElseIf (Left$(Flags, 1) = "-") Then
                        ' remove "-" prefix
                        Flags = Mid$(Flags, 2)
                        
                        ' are we modifying an existing user? we better be!
                        If (gAcc.Username <> vbNullString) Then
                            ' check for special flags
                            If (InStr(1, Flags, "B", vbBinaryCompare) <> 0) Then
                                ' unban user if found in banlist
                                For i = LBound(gBans) To UBound(gBans)
                                    If (StrComp(gBans(i).Username, user, _
                                            vbTextCompare) = 0) Then
                                        
                                        Call AddQ("/unban " & user)
                                    End If
                                Next i
                            ElseIf (InStr(1, Flags, "S", vbBinaryCompare) <> 0) Then
                                Call RemoveFromSafelist(strArray(0))
                            ElseIf (InStr(1, Flags, "Z", vbBinaryCompare) <> 0) Then
                                ' ...
                            End If
                        
                            ' remove specified flags
                            For i = 1 To Len(Flags)
                                gAcc.Flags = Replace(gAcc.Flags, Mid$(Flags, i, 1), vbNullString)
                            Next i
                        Else
                            ' return message
                            cmdRet(0) = "User not found."
                        
                            Exit Function
                        End If
                    Else
                        ' clear user flags
                        gAcc.Flags = vbNullString
                        
                        ' set rank to specified
                        gAcc.Access = rank
                    
                        ' check for special flags
                        If (InStr(1, Flags, "B", vbBinaryCompare) <> 0) Then
                            Call Ban(strArray(1) & " AutoBan", (AutoModSafelistValue - 1))
                        ElseIf (InStr(1, Flags, "S", vbBinaryCompare) <> 0) Then
                            Call AddToSafelist(strArray(1), Username)
                        ElseIf (InStr(1, Flags, "Z", vbBinaryCompare) <> 0) Then
                            Call WildCardBan(strArray(1), "Tagbanned", 1)
                        End If
                    
                        ' set user flags & check for duplicate entries
                        For i = 1 To Len(Flags)
                            currentCharacter = Mid$(Flags, i, 1)
                        
                            ' is flag valid (alphabetic)?
                            If (((Asc(currentCharacter) >= Asc("A")) And (Asc(currentCharacter) <= Asc("Z"))) Or _
                                ((Asc(currentCharacter) >= Asc("a")) And (Asc(currentCharacter) <= Asc("z")))) Then
                                
                                If (InStr(1, gAcc.Flags, currentCharacter, vbBinaryCompare) = 0) Then
                                    gAcc.Flags = gAcc.Flags & currentCharacter
                                End If
                            End If
                        Next i
                    End If
                End If
            Else
                ' clear flags
                gAcc.Flags = vbNullString
            
                ' set rank to specified
                gAcc.Access = rank
            End If

            ' grab path to database
            dbPath = GetFilePath("users.txt")

            ' does user already exist in database?
            For i = LBound(DB) To UBound(DB)
                If (StrComp(DB(i).Username, user, vbTextCompare) = 0) Then
                    If ((gAcc.Access <= 0) And (gAcc.Flags = vbNullString)) Then
                        ' remove user
                        Call RemoveItem(user, "users")
                        
                        ' log actions
                        If (BotVars.LogDBActions) Then
                            Call LogDBAction(RemEntry, Username, gAcc.Username, msgData)
                        End If
                        
                        ' reload database
                        Call LoadDatabase
                    Else
                        ' modify database entry
                        With DB(i)
                            .Access = gAcc.Access
                            .Flags = gAcc.Flags
                            .ModifiedBy = Username
                            .ModifiedOn = Now
                        End With
                    
                        ' commit modifications
                        Call WriteDatabase(dbPath)
                        
                        ' log actions
                        If (BotVars.LogDBActions) Then
                            Call LogDBAction(ModEntry, Username, gAcc.Username, msgData)
                        End If
                    End If
                    
                    ' we have found the
                    ' specified user
                    found = True
                    
                    Exit For
                End If
            Next i
            
            ' did we find a matching entry or not?
            If (found = False) Then
                ' redefine array size
                ReDim Preserve DB(UBound(DB) + 1)
                
                With DB(UBound(DB))
                    .Username = user
                    .Access = IIf((gAcc.Access >= 0), _
                        gAcc.Access, 0)
                    .Flags = gAcc.Flags
                    .ModifiedBy = Username
                    .ModifiedOn = Now
                    .AddedBy = Username
                    .AddedOn = Now
                End With
                
                ' commit modifications
                Call WriteDatabase(dbPath)
                
                ' log actions
                If (BotVars.LogDBActions) Then
                    Call LogDBAction(AddEntry, Username, gAcc.Username, msgData)
                End If
            End If
            
            ' check for errors & create message
            If (gAcc.Access > 0) Then
                tmpBuf = "Set " & user & "'s access to " & gAcc.Access
                
                ' was the user given the specified flags, too?
                If (Len(gAcc.Flags) > 0) Then
                    tmpBuf = tmpBuf & " and flags to " & gAcc.Flags & "."
                Else
                    tmpBuf = tmpBuf & "."
                End If
            Else
                ' was the user given the specified flags?
                If (Len(gAcc.Flags) > 0) Then
                    tmpBuf = "Set " & user & "'s flags to " & gAcc.Flags & "."
                Else
                    ' were rank and/or flags specified but not assigned?
                    If (Len(Flags) > 0) Then
                        tmpBuf = "You have specified an invalid rank and/or flags."
                    Else
                        tmpBuf = "The user " & gAcc.Username & " has been removed from the database."
                    End If
                End If
            End If
        End If
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnAdd

' TO DO:
' handle mmail command
Private Function OnMMail(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim Temp       As udtMail
    
    Dim strArray() As String
    Dim tmpBuf     As String ' temporary output buffer
    Dim c          As Integer
    Dim f          As Integer
    Dim Track      As Long
    
    strArray = Split(msgData, " ", 2)
            
    If (UBound(strArray) > 0) Then
        tmpBuf = "Mass mailing "

        With Temp
            .From = Username
            .Message = strArray(1)
            
            If (StrictIsNumeric(strArray(0))) Then
                'number games
                Track = Val(strArray(0))
                
                For c = 0 To UBound(DB)
                    If (DB(c).Access = Track) Then
                        .To = DB(c).Username
                        
                        Call AddMail(Temp)
                    End If
                Next c
                
                tmpBuf = tmpBuf & "to users with access " & Track
            Else
                'word games
                strArray(0) = UCase$(strArray(0))
                
                For c = 0 To UBound(DB)
                    For f = 1 To Len(strArray(1))
                        If (InStr(DB(c).Flags, Mid$(strArray(0), f, 1)) > 0) Then
                            .To = DB(c).Username
                            
                            Call AddMail(Temp)
                            
                            Exit For
                        End If
                    Next f
                Next c
                
                tmpBuf = tmpBuf & "to users with any of the flags " & strArray(0)
            End If
        End With
        
        tmpBuf = tmpBuf & " complete."
    Else
        tmpBuf = "Format: .mmail <flag(s)> <message> OR .mmail <access> <message>"
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnMMail

' handle mail command
Private Function OnMail(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim Temp       As udtMail

    Dim strArray() As String
    Dim tmpBuf     As String ' temporary output buffer
    
    strArray = Split(msgData, " ", 2)
    
    If (UBound(strArray) > 0) Then
        Temp.From = Username
        Temp.To = strArray(0)
        Temp.Message = strArray(1)
        
        Call AddMail(Temp)
        
        tmpBuf = "Added mail for " & strArray(0) & "."
    Else
        tmpBuf = "Error processing mail."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnMail

' handle designated command
Private Function OnDesignated(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    If ((MyFlags <> 2) And (MyFlags <> 18)) Then
        tmpBuf = "The bot does not currently have ops."
    ElseIf (gChannel.Designated = vbNullString) Then
        tmpBuf = "No users have been designated."
    Else
        tmpBuf = "I have designated """ & gChannel.Designated & """."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnDesignated

' handle flip command
Private Function OnFlip(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim i      As Integer
    Dim tmpBuf As String ' temporary output buffer

    Randomize
    
    i = (Rnd * 2)
    
    If (i = 0) Then
        tmpBuf = "Tails."
    Else
        tmpBuf = "Heads."
    End If
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnFlip

' handle about command
Private Function OnAbout(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer

    tmpBuf = ".: " & CVERSION & " by Stealth."
    
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnAbout

' handle server command
Private Function OnServer(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf As String ' temporary output buffer
    
    tmpBuf = "I am currently connected to " & BotVars.Server & "."
            
    ' return message
    cmdRet(0) = tmpBuf
End Function ' end function OnServer

' handle find command
Private Function OnFind(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    ' ...
    Dim gAcc     As udtGetAccessResponse

    Dim u        As String
    Dim tmpBuf() As String ' temporary output buffer
    
    ReDim Preserve tmpBuf(0)

    u = GetFilePath("users.txt")
            
    If (Dir$(u) = vbNullString) Then
        tmpBuf(0) = "No userlist available. Place a users.txt file" & _
            "in the bot's root directory."
    End If
    
    u = msgData
    
    If (Len(u) > 0) Then
        If (StrictIsNumeric(u)) Then
            ' execute search
            Call searchDatabase(tmpBuf(), , , Val(u))
        ElseIf (InStr(1, u, Space(1), vbBinaryCompare) <> 0) Then
            Dim lowerBound As String ' ...
            Dim upperBound As String ' ...
            
            ' grab range values
            If (InStr(1, u, " - ", vbBinaryCompare) <> 0) Then
                lowerBound = Mid$(u, 1, InStr(1, u, " - ", vbBinaryCompare) - 1)
                upperBound = Mid$(u, InStr(1, u, " - ", vbBinaryCompare) + Len(" - "))
            Else
                lowerBound = Mid$(u, 1, InStr(1, u, Space(1), vbBinaryCompare) - 1)
                upperBound = Mid$(u, InStr(1, u, Space(1), vbBinaryCompare) + 1)
            End If
            
            If ((StrictIsNumeric(lowerBound)) And _
                (StrictIsNumeric(upperBound))) Then
            
                ' execute search
                Call searchDatabase(tmpBuf(), , , CInt(Val(lowerBound)), CInt(Val(upperBound)))
            Else
                tmpBuf(0) = "You specified an invalid range for this command."
            End If
        ElseIf ((InStr(1, u, "*", vbBinaryCompare) <> 0) Or _
                (InStr(1, u, "?", vbBinaryCompare) <> 0)) Then
            
            ' execute search
            Call searchDatabase(tmpBuf(), , u)
        Else
            ' execute search
            Call searchDatabase(tmpBuf(), u)
        End If
    Else
        tmpBuf(0) = "Who do you want me to find?"
    End If
    
    ' return message
    cmdRet() = tmpBuf()
End Function ' end function OnFind

' handle whois command
Private Function OnWhoIs(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim tmpBuf() As String ' temporary output buffer
    Dim u        As String
    
    ReDim Preserve tmpBuf(0)

    u = msgData
            
    If (InBot) Then
        Call AddQ("/whois " & u, 1)
    End If
    
    Call OnFind(Username, dbAccess, u, InBot, tmpBuf())
    
    ' return message
    cmdRet() = tmpBuf()
End Function ' end function OnWhoIs

' handle findattr command
Private Function OnFindAttr(ByVal Username As String, ByRef dbAccess As udtGetAccessResponse, _
    ByVal msgData As String, ByVal InBot As Boolean, ByRef cmdRet() As String) As Boolean
    
    Dim u        As String
    Dim tmpBuf() As String ' temporary output buffer
    Dim tmpCount As Integer
    Dim i        As Integer
    Dim found    As Integer
    
    ReDim Preserve tmpBuf(tmpCount)

    u = UCase$(msgData)
            
    If (Len(u) > 0) Then
        ' execute search
        Call searchDatabase(tmpBuf(), , , , , u)
    Else
        tmpBuf(0) = "Please specify the flags you wish to search for."
    End If
    
    ' return message
    cmdRet() = tmpBuf()
End Function ' end function OnFindAttr

' requires public
Public Function Cache(ByVal Inpt As String, ByVal Mode As Byte, Optional ByRef Typ As String) As String
    Static s() As String
    Static sTyp As String
    Dim i As Integer
    
    'Debug.Print "cache input: " & Inpt
    
    If InStr(1, LCase$(Inpt), "in channel ", vbTextCompare) = 0 Then
        Select Case Mode
            Case 0
                For i = 0 To UBound(s)
                    Cache = Cache & Replace(s(i), ",", "") & Space(1)
                Next i
                
                'Debug.Print "cache output: " & Cache
                
                ReDim s(0)
                Typ = sTyp
                
            Case 1
                ReDim Preserve s(UBound(s) + 1)
                s(UBound(s)) = Inpt
                'Debug.Print "-> added " & Inpt & " to cache"
            Case 255
                ReDim s(0)
                sTyp = Typ
                
        End Select
    End If
End Function

Private Function Expand(ByVal s As String) As String
    Dim i As Integer
    Dim Temp As String
    
    If Len(s) > 1 Then
        For i = 1 To Len(s)
            Temp = Temp & Mid(s, i, 1) & Space(1)
        Next i
        Expand = Trim(Temp)
    Else
        Expand = s
    End If
End Function

Private Sub AddQ(ByVal s As String, Optional DND As Byte)
    Call frmChat.AddQ(s, DND)
End Sub

Private Sub WildCardBan(ByVal sMatch As String, ByVal smsgData As String, ByVal Banning As Byte) ', Optional ExtraMode As Byte)
    'Values for Banning byte:
    '0 = Kick
    '1 = Ban
    '2 = Unban
    
    Dim i     As Integer
    Dim Typ   As String
    Dim z     As String
    Dim iSafe As Integer
    
    If (smsgData = vbNullString) Then
        smsgData = sMatch
    End If
    
    sMatch = PrepareCheck(sMatch)
    
    'frmchat.addchat rtbcolors.ConsoleText, "Fired."
    'frmchat.addchat rtbcolors.ConsoleText, "Initial smsgData: " & smsgData
    'frmchat.addchat rtbcolors.ConsoleText, "Initial sMatch: " & sMatch
    
    Select Case (Banning)
        Case 1: Typ = "ban "
        Case 2: Typ = "unban "
        Case Else: Typ = "kick "
    End Select
    
    If (Dii) Then
        Typ = Typ & "*"
    End If
    
    If (colUsersInChannel.Count < 1) Then
        Exit Sub
    End If
    
    If (Banning <> 2) Then
        ' Kicking or Banning
    
        For i = 1 To colUsersInChannel.Count
            
            With colUsersInChannel.Item(i)
                If (Not (.IsSelf())) Then
                    z = PrepareCheck(.Username)
                    
                    If (z Like sMatch) Then
                        If (GetAccess(.Username).Access <= 20) Then
                            If (Not (.Safelisted)) Then
                                If (LenB(.Username) > 0 And ((.Flags <> 2) And (.Flags <> 18))) Then
                                    Call AddQ("/" & Typ & .Username & Space(1) & smsgData, 1)
                                End If
                            Else
                                iSafe = (iSafe + 1)
                            End If
                        Else
                            iSafe = (iSafe + 1)
                        End If
                    End If
                End If
            End With
        Next i
        
        If (iSafe > 0) Then
            If (StrComp(smsgData, ProtectMsg, vbTextCompare) <> 0) Then
                Call AddQ("Encountered " & iSafe & " safelisted user(s).")
            End If
        End If
        
    Else '// unbanning
    
        For i = 0 To UBound(gBans)
            If (sMatch = "*") Then
                Call AddQ("/" & Typ & gBans(i).UsernameActual, 1)
            Else
                z = PrepareCheck(gBans(i).UsernameActual)
                
                If (z Like sMatch) Then
                    Call AddQ("/" & Typ & gBans(i).UsernameActual, 1)
                End If
            End If
        Next i
    End If
End Sub

Private Function searchDatabase(ByRef arrReturn() As String, Optional user As String = vbNullString, _
    Optional ByVal match As String = vbNullString, Optional lowerBound As Integer = -1, _
    Optional upperBound As Integer = -1, Optional Flags As String = vbNullString) As Integer
    
    Dim i         As Integer
    Dim found     As Integer
    Dim tmpBuf()  As String
    Dim tmpCount  As Integer
    
    ' redefine array size
    ReDim Preserve tmpBuf(tmpCount)
    
    If (user <> vbNullString) Then
        ' store GetAccess() response
        Dim gAcc As udtGetAccessResponse
    
        ' grab user access
        gAcc = GetAccess(user)
        
        If (gAcc.Access > 0) Then
            If (gAcc.Flags <> vbNullString) Then
                tmpBuf(tmpCount) = "Found user " & gAcc.Username & ", with access " & gAcc.Access & _
                    " and flags " & gAcc.Flags & "."
            Else
                tmpBuf(tmpCount) = "Found user " & gAcc.Username & ", with access " & gAcc.Access & "."
            End If
        ElseIf (gAcc.Flags <> vbNullString) Then
            tmpBuf(tmpCount) = "Found user " & gAcc.Username & ", with flags " & gAcc.Flags & "."
        Else
            tmpBuf(tmpCount) = "No such user(s) found."
        End If
    Else
        tmpBuf(tmpCount) = "User(s) found: "
        
        For i = LBound(DB) To UBound(DB)
            Dim res As Boolean ' store result of access check
        
            If (DB(i).Username <> vbNullString) Then
                If (match <> vbNullString) Then
                    If (PrepareCheck(DB(i).Username) Like match) Then
                        res = True
                    End If
                ElseIf ((lowerBound >= 0) And (upperBound >= 0)) Then
                    If ((DB(i).Access >= lowerBound) And (DB(i).Access <= upperBound)) Then
                        res = True
                    End If
                ElseIf (lowerBound >= 0) Then
                    If (DB(i).Access = lowerBound) Then
                        res = True
                    End If
                ElseIf (Flags <> vbNullString) Then
                    Dim j As Integer ' ...
                
                    For j = 1 To Len(Flags)
                        If (InStr(1, DB(i).Flags, Mid$(Flags, j, 1), vbTextCompare) = 0) Then
                            Exit For
                        End If
                    Next j
                    
                    If (j = (Len(Flags) + 1)) Then
                        res = True
                    End If
                End If
                
                If (res = True) Then
                    tmpBuf(tmpCount) = tmpBuf(tmpCount) & ", " & _
                        DB(i).Username & IIf(DB(i).Access > 0, "\" & DB(i).Access, vbNullString) & _
                        IIf(DB(i).Flags <> vbNullString, "\" & DB(i).Flags, vbNullString)
                
                    If ((Len(tmpBuf(tmpCount)) > 80) And (i <> UBound(DB))) Then
                        ' resize array
                        ReDim Preserve tmpBuf(tmpCount + 1)
                        
                        ' prefix next message
                        tmpBuf(tmpCount + 1) = "User(s) found: "
                    
                        tmpBuf(tmpCount) = Replace(tmpBuf(tmpCount), " , ", " ")
                        tmpBuf(tmpCount) = Replace(tmpBuf(tmpCount), ": , ", ": ")
                        
                        ' postfix message
                        tmpBuf(tmpCount) = tmpBuf(tmpCount) & " [more]"
                        
                        ' increment array index
                        tmpCount = (tmpCount + 1)
                    End If
                    
                    ' increment found counter
                    found = (found + 1)
                End If
            End If
            
            ' reset boolean
            res = False
        Next i

        If (found = 0) Then
            tmpBuf(tmpCount) = "No such user(s) found."
        Else
            tmpBuf(tmpCount) = Replace(tmpBuf(tmpCount), " , ", " ") & "�"
            tmpBuf(tmpCount) = Replace(tmpBuf(tmpCount), " , ", " ")
            tmpBuf(tmpCount) = Replace(tmpBuf(tmpCount), ": , ", ": ")
            tmpBuf(tmpCount) = Replace(tmpBuf(tmpCount), ", �", vbNullString)
        
            If (InStr(1, tmpBuf(tmpCount), "�", vbTextCompare) > 0) Then
                tmpBuf(tmpCount) = Left$(tmpBuf(tmpCount), Len(tmpBuf(tmpCount)) - 1)
            End If
        End If
    End If
    
    ' return message
    arrReturn() = tmpBuf()
End Function

Private Function RemoveItem(ByVal rItem As String, File As String) As String
    Dim s() As String, f As Integer
    Dim Counter As Integer, strCompare As String
    Dim strAdd As String
    f = FreeFile
    
    If Dir$(GetFilePath(File & ".txt")) = vbNullString Then
        RemoveItem = "No %msgex% file found. Create one using .add, .addtag, or .shitlist."
        Exit Function
    End If
    
    Open (GetFilePath(File & ".txt")) For Input As #f
    If LOF(f) < 2 Then
        RemoveItem = "The %msgex% file is empty."
        Close #f
        Exit Function
    End If
    
    ReDim s(0)
    
    Do
        Line Input #f, strAdd
        s(UBound(s)) = strAdd
        ReDim Preserve s(0 To UBound(s) + 1)
    Loop Until EOF(f)
    
    Close #f
    
    For Counter = LBound(s) To UBound(s)
        strCompare = s(Counter)
        If strCompare <> vbNullString And strCompare <> " " Then
            If InStr(1, strCompare, " ", vbTextCompare) <> 0 Then
                strCompare = Left$(strCompare, InStr(1, strCompare, " ", vbTextCompare) - 1)
            End If
            
            If StrComp(LCase$(rItem), LCase$(strCompare), vbTextCompare) = 0 Then GoTo Successful
        End If
    Next Counter
    
    RemoveItem = "No such user found."
    
Successful:
    Close #f
    
    s(Counter) = vbNullString
    
    RemoveItem = "Successfully removed %msgex% " & Chr(34) & rItem & Chr(34) & "."
    
    Open (GetFilePath(File & ".txt")) For Output As #f
        For Counter = LBound(s) To UBound(s)
            If s(Counter) <> vbNullString And s(Counter) <> " " Then Print #f, s(Counter)
        Next Counter
theEnd:
    Close #f
End Function

' requires public
Public Function GetTagbans(ByVal Username As String) As String
    Dim f As Integer, strCompare As String, banMsg As String
    
    If Dir$(GetFilePath("tagbans.txt")) <> vbNullString Then
        f = FreeFile
        Open (GetFilePath("tagbans.txt")) For Input As #f
        If LOF(f) > 1 Then
            Username = PrepareCheck(Username)
            
            Do While Not EOF(f)
                Line Input #f, strCompare
                If InStr(1, strCompare, " ", vbBinaryCompare) > 0 Then
                
                    'Debug.Print "strc: " & strCompare
                    banMsg = Mid$(strCompare, InStr(strCompare, " ") + 1)
                    'Debug.Print "banm: " & banMsg
                    strCompare = Split(strCompare, " ")(0)
                    'Debug.Print "strc: " & strCompare
                    
                End If
                
                If Username Like PrepareCheck(strCompare) Then
                    GetTagbans = strCompare & IIf(Len(banMsg) > 0, Space(1) & banMsg, vbNullString)
                    Close #f
                    Exit Function
                End If
            Loop
        End If
        Close #f
    End If
End Function

Private Function GetSafelistMatches(ByVal Username As String) As String
    Dim f As Integer, strCompare As String, ret As String
    
    If Dir$(GetFilePath("safelist.txt")) <> vbNullString Then
        f = FreeFile
        Open (GetFilePath("safelist.txt")) For Input As #f
        If LOF(f) > 1 Then
            Username = PrepareCheck(Username)
            
            Do While Not EOF(f)
                Line Input #f, strCompare
                If InStr(1, strCompare, " ", vbBinaryCompare) > 0 Then
                    'Debug.Print "strc: " & strCompare
                    'banMsg = Mid$(strCompare, InStr(strCompare, " ") + 1)
                    'Debug.Print "banm: " & banMsg
                    strCompare = Split(strCompare, " ")(0)
                    'Debug.Print "strc: " & strCompare
                End If
                
                If Username Like PrepareCheck(strCompare) Then
                    ret = ret & strCompare & " "
                End If
            Loop
        End If
        Close #f
    End If
    
    GetSafelistMatches = ReversePrepareCheck(Trim(ret))
End Function

' requires public
Public Function GetSafelist(ByVal Username As String) As Boolean
    Dim i As Long
    
    On Error Resume Next
    Username = PrepareCheck(Username)
    GetSafelist = False
    
    If Not bFlood Then
        
        For i = 1 To colSafelist.Count
            If Username Like colSafelist.Item(i).Name Then
                GetSafelist = True
                Exit Function
            End If
        Next i
    
    Else
        
        For i = 0 To (UBound(gFloodSafelist) - 1)
            If Username Like gFloodSafelist(i) Then
                GetSafelist = True
                Exit Function
            End If
        Next i

    End If
    
End Function

' requires public
Public Function GetShitlist(ByVal Username As String) As String
    Dim strCompare As String, toCheck As String
    Dim Temp As String
    Dim f As Integer
    f = FreeFile
    
    Username = LCase$(Username)
    
    On Error Resume Next
    Temp = GetFilePath("autobans.txt")
    
    If Dir$(Temp) <> vbNullString Then Open Temp For Input As #f Else GoTo theEnd
    
    If LOF(f) < 2 Then GoTo theEnd
    Do
        Line Input #f, strCompare
        toCheck = LCase$(strCompare)
        If InStr(1, toCheck, " ", vbTextCompare) <> 0 Then
            toCheck = Left$(strCompare, InStr(1, strCompare, " ", vbTextCompare) - 1)
        End If
        
        If StrComp(toCheck, Username, vbTextCompare) = 0 Then
            If InStr(1, strCompare, " ", vbTextCompare) = 0 Then
                GetShitlist = Username & " Shitlisted"
            Else
                GetShitlist = Username & Space(1) & Right(strCompare, Len(strCompare) - InStr(1, strCompare, " ", vbTextCompare))
            End If
            Close #f
            Exit Function
        End If
    Loop Until EOF(f)
theEnd:
    Close #f
End Function

' requires public
Public Function GetPing(ByVal Username As String) As Long
    Dim i As Integer
    
    i = UsernameToIndex(Username)
    
    If i > 0 Then
        GetPing = colUsersInChannel.Item(i).Ping
    Else
        GetPing = -3
    End If
End Function

' requires public
Public Function PrepareCheck(ByVal toCheck As String) As String
    toCheck = Replace(toCheck, "[", "�")
    toCheck = Replace(toCheck, "]", "�")
    toCheck = Replace(toCheck, "~", "�")
    toCheck = Replace(toCheck, "#", "�")
    toCheck = Replace(toCheck, "-", "�")
    toCheck = Replace(toCheck, "&", "�")
    toCheck = Replace(toCheck, "@", "�")
    toCheck = Replace(toCheck, "{", "�")
    toCheck = Replace(toCheck, "}", "�")
    toCheck = Replace(toCheck, "^", "�")
    toCheck = Replace(toCheck, "`", "�")
    toCheck = Replace(toCheck, "_", "�")
    toCheck = Replace(toCheck, "+", "�")
    toCheck = Replace(toCheck, "$", "�")
    PrepareCheck = LCase$(toCheck)
End Function

' requires public
Public Function ReversePrepareCheck(ByVal toCheck As String) As String
    toCheck = Replace(toCheck, "�", "[")
    toCheck = Replace(toCheck, "�", "]")
    toCheck = Replace(toCheck, "�", "~")
    toCheck = Replace(toCheck, "�", "#")
    toCheck = Replace(toCheck, "�", "-")
    toCheck = Replace(toCheck, "�", "&")
    toCheck = Replace(toCheck, "�", "@")
    toCheck = Replace(toCheck, "�", "{")
    toCheck = Replace(toCheck, "�", "}")
    toCheck = Replace(toCheck, "�", "^")
    toCheck = Replace(toCheck, "�", "`")
    toCheck = Replace(toCheck, "�", "_")
    toCheck = Replace(toCheck, "�", "+")
    toCheck = Replace(toCheck, "�", "$")
    ReversePrepareCheck = LCase$(toCheck)
End Function

Private Sub DBRemove(ByVal s As String)
    
    Dim i As Integer
    Dim c As Integer
    Dim n As Integer
    Dim t() As udtDatabase
    Dim Temp As String
    s = LCase$(s)
    
    For i = LBound(DB) To UBound(DB)
        If StrComp(DB(i).Username, s, vbTextCompare) = 0 Then
            ReDim t(0 To UBound(DB) - 1)
            For c = LBound(DB) To UBound(DB)
                If c <> i Then
                    t(n) = DB(c)
                    n = n + 1
                End If
            Next c
            
            ReDim DB(UBound(t))
            For c = LBound(t) To UBound(t)
                DB(c) = t(c)
            Next c
            Exit Sub
        End If
    Next i
    
    n = FreeFile
    
    Temp = GetFilePath("users.txt")
    
    Open Temp For Output As #n
    
    For i = LBound(DB) To UBound(DB)
        Print #n, DB(i).Username & Space(1) & DB(i).Access & Space(1) & DB(i).Flags
    Next i
    
    Close #n
    
End Sub

' requires public
Public Sub LoadDatabase()
    ReDim DB(0)
    
    Dim s As String, X() As String
    Dim Path As String
    Dim i As Integer, f As Integer
    Dim gA As udtDatabase, found As Boolean
    
    Path = GetFilePath("users.txt")
    
    On Error Resume Next
    
    If Dir$(Path) <> vbNullString Then
        f = FreeFile
        Open Path For Input As #f
            
        If LOF(f) > 1 Then
            Do
                
                Line Input #f, s
                
                If InStr(1, s, " ", vbTextCompare) > 0 Then
                    X() = Split(s, " ")
                    
                    If UBound(X) > 0 Then
                        ReDim Preserve DB(i)
                        With DB(i)
                            .Username = X(0)
                            
                            If StrictIsNumeric(X(1)) Then
                                .Access = Val(X(1))
                            Else
                                If X(1) <> "%" Then
                                    .Flags = X(1)
                                    
                                    If InStr(X(1), "S") > 0 Then
                                        AddToSafelist .Username
                                        .Flags = Replace(.Flags, "S", "")
                                    End If
                                End If
                            End If
                            
                            If UBound(X) > 1 Then
                                If StrictIsNumeric(X(2)) Then
                                    .Access = Int(X(2))
                                Else
                                    If X(2) <> "%" Then
                                        .Flags = X(2)
                                        
                                        If InStr(X(2), "S") > 0 Then
                                            AddToSafelist .Username
                                            .Flags = Replace(.Flags, "S", "")
                                        End If
                                    End If
                                End If
                                
                                '  0        1       2       3       4       5       6
                                ' username access flags addedby addedon modifiedby modifiedon
                                If UBound(X) > 2 Then
                                    .AddedBy = X(3)
                                    
                                    If UBound(X) > 3 Then
                                        .AddedOn = CDate(Replace(X(4), "_", " "))
                                        
                                        If UBound(X) > 4 Then
                                            .ModifiedBy = X(5)
                                            
                                            If UBound(X) > 5 Then
                                                .ModifiedOn = CDate(Replace(X(6), "_", " "))
                                            End If
                                        End If
                                    End If
                                End If
                                
                            End If
                            
                            If .Access > 999 Then .Access = 999
                        End With

                        i = i + 1
                    End If
                End If
                
            Loop While Not EOF(f)
        End If
        
        Close #f
    End If
    
    ' 9/13/06: Add the bot owner 1000
    If LenB(BotVars.BotOwner) > 0 Then
        For i = 0 To UBound(DB)
            If StrComp(DB(i).Username, BotVars.BotOwner, vbTextCompare) = 0 Then
                DB(i).Access = 1000
                found = True
                Exit For
            End If
        Next i
        
        If Not found Then
            ReDim Preserve DB(UBound(DB) + 1)
            DB(UBound(DB)).Username = BotVars.BotOwner
            DB(UBound(DB)).Access = 1000
        End If
    End If
End Sub

Private Function ValidateAccess(ByRef Acc As udtGetAccessResponse, ByVal CWord As String) As Boolean

    Dim Temp As String, i As Integer, n As Integer
    
    If LenB(CWord) > 0 Then
        
        'CWord = Mid$(CWord, 2)
        
        If LenB(ReadINI("DisabledCommands", CWord, "access.ini")) > 0 Or ReadINI("DisabledCommands", "universal", "access.ini") = "Y" Then
            ValidateAccess = False
            Exit Function
        End If
        
        Temp = UCase$(ReadINI("Flags", CWord, "access.ini"))
        
        If Len(Temp) > 0 Then
            For i = 1 To Len(Temp)
                If InStr(1, Acc.Flags, Mid(Temp, i, 1)) > 0 Then
                    ValidateAccess = True
                    Exit Function
                End If
            Next i
        End If
        
        n = AccessNecessary(CWord, i)
        
        'Debug.Print "N: " & n
        'Debug.Print "I: " & i
        'Debug.Print "A: " & Acc.Access
        
        If Acc.Access = -1 And i = 1 Then Acc.Access = 0
        '// needs to be set to 0 so that the below statements work when
        '// an entry is present in the access.ini file.
        
        If Acc.Access >= n Then
            'Debug.Print "Init"
            If Acc.Access > 0 Then
                ValidateAccess = True
                Exit Function
            Else
                If i = 1 Then
                    If Not (StrComp(CWord, "ver", vbBinaryCompare) = 0) Then '// hardcoded fix for .ver exploit :(
                        ValidateAccess = True
                        Exit Function
                    Else
                        If Acc.Access > 0 Then ValidateAccess = True
                    End If
                End If
            End If
        End If
        
        If InStr(1, Acc.Flags, "A", vbBinaryCompare) > 0 Then
            ValidateAccess = True
            Exit Function
        End If
        
    End If
    
End Function

Private Function AccessNecessary(ByVal CW As String, Optional ByRef i As Integer) As Integer
    
    'Debug.Print CW & vbTab & "[" & ReadINI("Numeric", CW, "access.ini") & "]"
    If Len(ReadINI("Numeric", CW, "access.ini")) > 0 Then
        
        AccessNecessary = Val(ReadINI("Numeric", CW, "access.ini"))
        i = 1
        
    Else
        Select Case CW
            Case "getmail"
                AccessNecessary = 0
            Case "find", "whois", "about", "server", "add", "set", "whoami", "cq", "scq", "designated", "about", "ver", "version", "mail", "findattr", "findflag", "flip", "bmail", "roll", "findr"
                AccessNecessary = 20
            Case "time", "trigger", "getping", "pingme", "checkmail"
                AccessNecessary = 40
            Case "say", "shout", "ignore", "unignore", "addquote", "quote", "away", "back", "ping", "uptime", "mp3", "ign", "owner"
                AccessNecessary = 50
            Case "vote", "voteban", "votekick", "tally", "info", "expand", "math", "eval", "where", "safecheck", "cancel"
                AccessNecessary = 50
            Case "kick", "ban", "unban", "lastwhisper", "define", "newdef", "def", "fadd", "frem", "bancount", "allseen", "levelbans", "lw", "deldef"
                AccessNecessary = 60
            Case "d2levelbans", "tagcheck", "detail", "dbd", "slcheck", "shitcheck"
                AccessNecessary = 60
            Case "shitlist", "shitdel", "safeadd", "safedel", "safelist", "tagbans", "tagadd", "tagdel", "protect", "pban", "shitadd", "sl"
                AccessNecessary = 70
            Case "mimic", "nomimic", "cmdadd", "addcmd", "cmddel", "delcmd", "cmdlist", "plist", "setpmsg", "mmail", "addtag", "cbans", "setcmdaccess"
                AccessNecessary = 70
            Case "padd", "addphrase", "phrases", "delphrase", "pdel", "pon", "poff", "phrasebans", "pstatus", "ipban", "banned", "notify", "denotify"
                AccessNecessary = 70
            Case "reconnect", "des", "designate", "rejoin", "settrigger", "igpriv", "unigpriv", "rem", "del", "sethome", "idle", "rj", "allowmp3"
                AccessNecessary = 80
            Case "next", "play", "stop", "setvol", "fos", "pause", "shuffle", "repeat"
                If Not BotVars.DisableMP3Commands Then
                    AccessNecessary = 80
                Else
                    AccessNecessary = 1000
                End If
                
            Case "idletime", "idletype", "block", "filter", "whispercmds", "profile", "greet", "levelban", "d2levelban", "clist", "clientbans", "cbans", "cadd", "cdel", "koy", "plugban", "useitunes", "setidle", "usewinamp"
                AccessNecessary = 80
            Case "join", "home", "resign", "setname", "setpass", "setserver", "quiettime", "giveup", "readfile", "chpw", "ib", "cb", "cs", "clan", "sweepban", "sweepignore", "op", "setkey", "setexpkey", "idlebans"
                AccessNecessary = 90
            Case "c", "exile", "unexile"
                AccessNecessary = 90
            Case "clearbanlist", "cbl"
                AccessNecessary = 90
            Case "quit", "locktext", "efp", "floodmode", "loadwinamp", "setmotd", "invite", "peonban"
                AccessNecessary = 100
            Case Else
                AccessNecessary = 1000
        End Select
    End If
    
End Function

' requires public
Public Function GetRandomQuote() As String
    Dim Rand As Integer, f As Integer
    Dim s As String
    Dim colQuotes As Collection
    
    Set colQuotes = New Collection
    
   On Error GoTo GetRandomQuote_Error

    If LenB(Dir$(GetFilePath("quotes.txt"))) > 0 Then
    
        f = FreeFile
        Open (GetFilePath("quotes.txt")) For Input As #f
        
        If LOF(f) > 1 Then
        
            Do
                Line Input #f, s
                
                s = Trim(s)
                
                If LenB(s) > 0 Then
                    colQuotes.Add s
                End If
            Loop Until EOF(f)
            
            Randomize
            Rand = Rnd * colQuotes.Count
            
            If Rand <= 0 Then
                Rand = 1
            End If
            
            If Len(colQuotes.Item(Rand)) < 1 Then
                Randomize
                Rand = Rnd * colQuotes.Count
                
                If Rand <= 0 Then
                    Rand = 1
                End If
            End If
            
            GetRandomQuote = colQuotes.Item(Rand)

        End If
        
        Close #f
        
    End If
    
    If Left$(GetRandomQuote, 1) = "/" Then GetRandomQuote = " " & GetRandomQuote

GetRandomQuote_Exit:
    Set colQuotes = Nothing
    
    Exit Function

GetRandomQuote_Error:

    Debug.Print "Error " & Err.Number & " (" & Err.Description & ") in procedure GetRandomQuote of Module modCommandCode"
    Resume GetRandomQuote_Exit
End Function

' Writes database to disk
' Updated 9/13/06 for new features
Private Sub WriteDatabase(ByVal u As String)
    Dim f As Integer, i As Integer
    
   On Error GoTo WriteDatabase_Exit

    f = FreeFile
    
    Open u For Output As #f
                
    For i = LBound(DB) To UBound(DB)
        If (DB(i).Access > 0 Or Len(DB(i).Flags) > 0) Then
            Print #f, DB(i).Username;
            Print #f, " " & DB(i).Access;
            Print #f, " " & IIf(Len(DB(i).Flags) > 0, DB(i).Flags, "%");
            Print #f, " " & IIf(Len(DB(i).AddedBy) > 0, DB(i).AddedBy, "%");
            Print #f, " " & IIf(DB(i).AddedOn > 0, DateCleanup(DB(i).AddedOn), "%");
            Print #f, " " & IIf(Len(DB(i).ModifiedBy) > 0, DB(i).ModifiedBy, "%");
            Print #f, " " & IIf(DB(i).ModifiedOn > 0, DateCleanup(DB(i).ModifiedOn), "%");
            Print #f, vbCr
        End If
    Next i

WriteDatabase_Exit:
    Close #f
    
   Exit Sub

WriteDatabase_Error:

    Debug.Print "Error " & Err.Number & " (" & Err.Description & ") in procedure WriteDatabase of Module modCommandCode"
    Resume WriteDatabase_Exit
End Sub

Private Function GetDBDetail(ByVal Username As String) As String
    Dim sRetAdd As String, sRetMod As String
    Dim i As Integer
    
    For i = 0 To UBound(DB)
        With DB(i)
            If StrComp(Username, .Username, vbTextCompare) = 0 Then
                If .AddedBy <> "%" And LenB(.AddedBy) > 0 Then
                    sRetAdd = " was added by " & .AddedBy & " on " & .AddedOn & "."
                End If
                
                If .ModifiedBy <> "%" And LenB(.ModifiedBy) > 0 Then
                    If (.AddedOn <> .ModifiedOn) Or (.AddedBy <> .ModifiedBy) Then
                        sRetMod = " was last modified by " & .ModifiedBy & " on " & .ModifiedOn & "."
                    Else
                        sRetMod = " have not been modified since they were added."
                    End If
                End If
                
                If LenB(sRetAdd) > 0 Or LenB(sRetMod) > 0 Then
                    If LenB(sRetAdd) > 0 Then
                        GetDBDetail = DB(i).Username & sRetAdd & " They" & sRetMod
                    Else
                        'no add, but we could have a modify
                        GetDBDetail = DB(i).Username & sRetMod
                    End If
                Else
                    GetDBDetail = "No detailed information is available for that user."
                End If
                
                Exit Function
            End If
        End With
    Next i
    
    GetDBDetail = "That user was not found in the database."
End Function

' requires public
Public Function DateCleanup(ByVal tDate As Date) As String
    Dim t As String
    
    t = Format(tDate, "dd-MM-yyyy_HH:MM:SS")
    
    DateCleanup = Replace(t, " ", "_")
End Function

Private Function GetAccessINIValue(ByVal sKey As String, Optional ByVal Default As Long) As Long
    Dim s As String, l As Long
    
    s = ReadINI("Numeric", sKey, "access.ini")
    l = Val(s)
    
    If l > 0 Then
        GetAccessINIValue = l
    Else
        If Default > 0 Then
            GetAccessINIValue = Default
        Else
            GetAccessINIValue = 100
        End If
    End If
End Function
