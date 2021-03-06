Attribute VB_Name = "modBNLS"
Option Explicit
Private Const OBJECT_NAME As String = "modBNLS"

Private Const BNLS_CHOOSENLSREVISION  As Byte = &HD
Private Const BNLS_AUTHORIZE          As Byte = &HE
Private Const BNLS_AUTHORIZEPROOF     As Byte = &HF
Private Const BNLS_REQUESTVERSIONBYTE As Byte = &H10
Private Const BNLS_VERSIONCHECKEX2    As Byte = &H1A

Public BNLSAuthorized As Boolean

Public Function BNLSRecvPacket(ByVal pBuff As clsDataBuffer, Optional ByVal ScriptSource As Boolean = False) As Boolean
On Error GoTo ERROR_HANDLER:
    Dim PacketID As Byte
    Dim PacketLen As Long

    BNLSRecvPacket = True

    If pBuff.HandleRecvData(PacketID, PacketLen, stBNLS, phtMCP, ScriptSource) Then
        Select Case PacketID
            
            Case BNLS_AUTHORIZE:          Call RECV_BNLS_AUTHORIZE(pBuff)
            Case BNLS_AUTHORIZEPROOF:     Call RECV_BNLS_AUTHORIZEPROOF(pBuff)
            Case BNLS_REQUESTVERSIONBYTE: Call RECV_BNLS_REQUESTVERSIONBYTE(pBuff)
            Case BNLS_VERSIONCHECKEX2:    Call RECV_BNLS_VERSIONCHECKEX2(pBuff)
            
            Case Else:
                BNLSRecvPacket = False
                If (MDebug("debug") And (MDebug("all") Or MDebug("unknown"))) Then
                    Call frmChat.AddChat(g_Color.ErrorMessageText, StringFormat("[BNLS] Unhandled packet 0x{0}", ZeroOffset(CLng(PacketID), 2)))
                    Call frmChat.AddChat(g_Color.ErrorMessageText, StringFormat("[BNLS] Packet data: {0}{1}", vbNewLine, pBuff.DebugOutput))
                End If
        
        End Select
    End If
    
    Exit Function
ERROR_HANDLER:
    Call frmChat.AddChat(g_Color.ErrorMessageText, StringFormat("Error: #{0}: {1} in {2}.BNLSRecvPacket()", Err.Number, Err.Description, OBJECT_NAME))
End Function

'*******************************
'BNLS_AUTHORIZE (0x0E) S->C
'*******************************
' (DWORD) Server Token
'*******************************
Private Sub RECV_BNLS_AUTHORIZE(pBuff As clsDataBuffer)
On Error GoTo ERROR_HANDLER:

    Call SEND_BNLS_AUTHORIZEPROOF(pBuff.GetDWord)

    Exit Sub
ERROR_HANDLER:
    Call frmChat.AddChat(g_Color.ErrorMessageText, StringFormat("Error: #{0}: {1} in {2}.RECV_BNLS_AUTHORIZE()", Err.Number, Err.Description, OBJECT_NAME))
End Sub

'*******************************
'BNLS_AUTHORIZE (0x0E) C->S
'*******************************
' (String) Bot ID
'*******************************
Public Sub SEND_BNLS_AUTHORIZE(Optional sBotID As String = vbNullString)
On Error GoTo ERROR_HANDLER:

    Dim pBuff As clsDataBuffer
    Set pBuff = New clsDataBuffer
    pBuff.InsertNTString IIf(LenB(sBotID) = 0, "stealth", sBotID)
    pBuff.vLSendPacket BNLS_AUTHORIZE
    Set pBuff = Nothing

    Exit Sub
ERROR_HANDLER:
    Call frmChat.AddChat(g_Color.ErrorMessageText, StringFormat("Error: #{0}: {1} in {2}.SEND_BNLS_AUTHORIZE()", Err.Number, Err.Description, OBJECT_NAME))
End Sub

'*******************************
'BNLS_AUTHORIZEPROOF (0x0F) S->C
'*******************************
' (DWORD) Server Token
'*******************************
Private Sub RECV_BNLS_AUTHORIZEPROOF(pBuff As clsDataBuffer)
On Error GoTo ERROR_HANDLER:

    BNLSAuthorized = True
    Call frmChat.Event_BNLSAuthEvent(True)
    
    Call frmChat.Event_BNetConnecting
    
    frmChat.sckBNet.Connect

    Exit Sub
ERROR_HANDLER:
    Call frmChat.AddChat(g_Color.ErrorMessageText, StringFormat("Error: #{0}: {1} in {2}.RECV_BNLS_AUTHORIZEPROOF()", Err.Number, Err.Description, OBJECT_NAME))
End Sub

'*******************************
'BNLS_AUTHORIZEPROOF (0x0F) C->S
'*******************************
' (DWORD) Password Checksum
'*******************************
Private Sub SEND_BNLS_AUTHORIZEPROOF(lServerToken As Long, Optional sPassword As String = vbNullString)
On Error GoTo ERROR_HANDLER:

    Dim cCRC      As clsCRC32
    Dim lChecksum As Long
    Dim pBuff     As clsDataBuffer
    
    Set cCRC = New clsCRC32
    
    lChecksum = cCRC.CRC32(StringFormat("{0}{1}", _
        IIf(LenB(sPassword) = 0, "gn1ftx14oc", sPassword), _
        ZeroOffset(lServerToken, 8)))
    
    Set pBuff = New clsDataBuffer
    
    pBuff.InsertDWord lChecksum
    pBuff.vLSendPacket BNLS_AUTHORIZEPROOF
    
    Set cCRC = Nothing
    Set pBuff = Nothing
    
    Exit Sub
ERROR_HANDLER:
    Call frmChat.AddChat(g_Color.ErrorMessageText, StringFormat("Error: #{0}: {1} in {2}.SEND_BNLS_AUTHORIZEPROOF()", Err.Number, Err.Description, OBJECT_NAME))
End Sub

'************************************
'BNLS_REQUESTVERSIONBYTE (0x10) S->C
'************************************
' (DWORD) Product ID (0 if failure)
' (DWORD) Version Byte (Not included if failure)
'************************************
Private Sub RECV_BNLS_REQUESTVERSIONBYTE(pBuff As clsDataBuffer)
On Error GoTo ERROR_HANDLER:
    
    Dim lVerByte     As Long
    
    If (Not pBuff.GetDWord = 0) Then
        lVerByte = pBuff.GetDWord
        Config.SetVersionByte GetProductKey(), lVerByte 'Save BNLS's Version Byte
        Call Config.Save
        
        Select Case modBNCS.GetLogonSystem()
            Case modBNCS.BNCS_NLS: Call modBNCS.SEND_SID_AUTH_INFO(lVerByte)
            Case modBNCS.BNCS_OLS:
                modBNCS.SEND_SID_CLIENTID2
                modBNCS.SEND_SID_LOCALEINFO
                modBNCS.SEND_SID_STARTVERSIONING lVerByte
            Case modBNCS.BNCS_LLS:
                modBNCS.SEND_SID_CLIENTID
                modBNCS.SEND_SID_STARTVERSIONING lVerByte
            Case Else:
                frmChat.AddChat g_Color.ErrorMessageText, StringFormat("Unknown Logon System Type: {0}", modBNCS.GetLogonSystem())
                frmChat.AddChat g_Color.ErrorMessageText, "Please visit http://www.stealthbot.net/sb/issues/?unknownLogonType for information regarding this error."
                frmChat.DoDisconnect
        End Select
    Else
        frmChat.AddChat g_Color.ErrorMessageText, "[BNLS] Version byte request failed!"
        frmChat.DoDisconnect
    End If
    
    Exit Sub
ERROR_HANDLER:
    Call frmChat.AddChat(g_Color.ErrorMessageText, StringFormat("Error: #{0}: {1} in {2}.RECV_BNLS_REQUESTVERSIONBYTE()", Err.Number, Err.Description, OBJECT_NAME))
End Sub

'************************************
'BNLS_REQUESTVERSIONBYTE (0x10) C->S
'************************************
' (DWORD) ProductID
'************************************
Public Sub SEND_BNLS_REQUESTVERSIONBYTE(Optional sProduct As String = vbNullString)
On Error GoTo ERROR_HANDLER:

    Dim pBuff As clsDataBuffer
    Set pBuff = New clsDataBuffer
    
    pBuff.InsertDWord GetBNLSProductID(IIf(LenB(sProduct) = 0, BotVars.Product, sProduct))
    pBuff.vLSendPacket BNLS_REQUESTVERSIONBYTE
    
    Set pBuff = Nothing
    
    Exit Sub
ERROR_HANDLER:
    Call frmChat.AddChat(g_Color.ErrorMessageText, StringFormat("Error: #{0}: {1} in {2}.SEND_BNLS_REQUESTVERSIONBYTE()", Err.Number, Err.Description, OBJECT_NAME))
End Sub

'************************************
'BNLS_VERSIONCHECKEX2 (0x1A) S->C
'************************************
' (DWORD) Success*
' (DWORD) Version.
' (DWORD) Checksum.
' (STRING) Version check stat string.
' (DWORD) Cookie.
' (DWORD) Version Byte
'************************************
Private Sub RECV_BNLS_VERSIONCHECKEX2(pBuff As clsDataBuffer)
On Error GoTo ERROR_HANDLER:
    Dim lVersionByte As Long

    If (pBuff.GetDWord = 1) Then
        ds.CRevVersion = pBuff.GetDWord
        ds.CRevChecksum = pBuff.GetDWord
        ds.CRevResult = pBuff.GetString
        pBuff.GetDWord
        lVersionByte = pBuff.GetDWord
        
        Select Case modBNCS.GetLogonSystem()
            Case modBNCS.BNCS_NLS: Call modBNCS.SEND_SID_AUTH_CHECK
            Case modBNCS.BNCS_OLS: Call modBNCS.SEND_SID_REPORTVERSION(lVersionByte)
            Case modBNCS.BNCS_LLS: Call modBNCS.SEND_SID_REPORTVERSION(lVersionByte)
            Case Else:
                frmChat.AddChat g_Color.ErrorMessageText, StringFormat("Unknown Logon System Type: {0}", modBNCS.GetLogonSystem())
                frmChat.AddChat g_Color.ErrorMessageText, "Please visit http://www.stealthbot.net/sb/issues/?unknownLogonType for information regarding this error."
                frmChat.DoDisconnect
        End Select
    Else
        Call frmChat.HandleBnlsError(0, StringFormat("BNLS has failed CheckRevision (Product: {0}).", StrReverse(BotVars.Product)), True)
    End If
    
    Exit Sub
ERROR_HANDLER:
    Call frmChat.AddChat(g_Color.ErrorMessageText, StringFormat("Error: #{0}: {1} in {2}.RECV_BNLS_VERSIONCHECKEX2()", Err.Number, Err.Description, OBJECT_NAME))
End Sub

'************************************
'BNLS_VERSIONCHECKEX2 (0x1A) C->S
'************************************
' (DWORD) Product ID.*
' (DWORD) Flags.**
' (DWORD) Cookie.
' (FILETIME) CRev Archive File Time
' (STRING) CRev Archive File Name
' (STRING) CRev Seed Values
'************************************
Public Sub SEND_BNLS_VERSIONCHECKEX2(sCRevFileTime As String, sCRevFileName As String, sCRevSeeds As String, Optional sProduct As String = vbNullString, Optional lFlags As Long = 0, Optional lCookie As Long = 1)
On Error GoTo ERROR_HANDLER:

    Dim pBuff As clsDataBuffer
    Set pBuff = New clsDataBuffer
    
    With pBuff
        .InsertDWord GetBNLSProductID(sProduct)
        .InsertDWord lFlags
        .InsertDWord lCookie
        .InsertNonNTString sCRevFileTime
        .InsertNTString sCRevFileName
        .InsertNTString sCRevSeeds
        .vLSendPacket BNLS_VERSIONCHECKEX2
    End With
    
    Set pBuff = Nothing
    
    Exit Sub
ERROR_HANDLER:
    Call frmChat.AddChat(g_Color.ErrorMessageText, StringFormat("Error: #{0}: {1} in {2}.SEND_BNLS_VERSIONCHECKEX2()", Err.Number, Err.Description, OBJECT_NAME))
End Sub

'===================================================================================================
Public Function GetBNLSProductID(Optional ByVal sProdID As String = vbNullString) As Long
    If (LenB(sProdID) = 0) Then sProdID = BotVars.Product

    GetBNLSProductID = GetProductInfo(sProdID).BNLS_ID
End Function
