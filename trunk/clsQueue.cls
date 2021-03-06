VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "clsQueue"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
' clsQueue.cls
' Copyright (C) 2008 Eric Evans

Option Explicit

Private Const MAX_PRIORITY_LEVEL = 100

Private m_QueueObjs() As clsQueueObj
Private m_ObjCount    As Long
Private m_LastUser    As String
Private m_LastObjID   As Double

Private Sub Class_Initialize()
    m_LastObjID = 1

    Clear
End Sub

Private Sub Class_Terminate()
    Clear
End Sub

Public Sub Push(ByVal obj As clsQueueObj)
    On Error GoTo ERROR_HANDLER
    
    Dim Index As Long
    Dim i     As Long
    
    Index = m_ObjCount
    
    If (m_ObjCount >= 1) Then
        For i = 0 To m_ObjCount - 1
            If (obj.Priority < m_QueueObjs(i).Priority) Then
                Index = i
                
                Exit For
            End If
        Next i
    
        ReDim Preserve m_QueueObjs(0 To m_ObjCount)
    End If

    If (Index < m_ObjCount) Then
        For i = m_ObjCount To Index + 1 Step -1
            Set m_QueueObjs(i) = m_QueueObjs(i - 1)
        Next i
    End If
    
    obj.ID = m_LastObjID
    
    Set m_QueueObjs(Index) = obj
    
    m_ObjCount = (m_ObjCount + 1)
    m_LastObjID = (m_LastObjID + 1)

    RunInAll "Event_MessageQueued", obj.ID, obj.Message, obj.Tag
    
    Exit Sub

ERROR_HANDLER:

    ' overflow - likely due to message id size
    If (Err.Number = 6) Then
        m_LastObjID = 0
        
        Resume Next
    End If

    Call frmChat.AddChat(vbRed, "Error: " & Err.Description & " in clsQueue.Push().")

    Exit Sub
End Sub

Public Function Pop() As clsQueueObj
    Set Pop = New clsQueueObj

    Set Pop = m_QueueObjs(0)
    
    RemoveItem 0

End Function ' end function Pop

Public Function Peek() As clsQueueObj
    Set Peek = New clsQueueObj

    Set Peek = m_QueueObjs(0)
End Function ' end function Peek

Public Function Item(ByVal Index As Long) As clsQueueObj
    If ((Index < 0) Or (Index > m_ObjCount - 1)) Then
        Set Item = New clsQueueObj
    
        Exit Function
    End If

    Set Item = m_QueueObjs(Index)
End Function

Public Function ItemByID(ByVal i As Double) As clsQueueObj
    Dim j As Long

    For j = 0 To m_ObjCount - 1
        If (m_QueueObjs(j).ID = i) Then
            Set ItemByID = m_QueueObjs(j)
        
            Exit Function
        End If
    Next j
    
    Set ItemByID = New clsQueueObj
End Function

Public Property Get Count() As Long
    Count = m_ObjCount
End Property

Public Function RemoveLines(ByVal Match As String) As Integer
    Dim curQueueObj As clsQueueObj
    Dim i           As Long
    Dim found       As Long
    
    Do
        Set curQueueObj = m_QueueObjs(i)

        If (PrepareCheck(curQueueObj.Message) Like PrepareCheck(Match)) Then
            RemoveItem i
            
            found = (found + 1)
            
            i = 0
        Else
            i = (i + 1)
        End If
    Loop While (i < Count())
    
    RemoveLines = found
End Function

Public Sub RemoveItem(ByVal Index As Long)
    Dim i As Long

    If ((Index < 0) Or (Index > m_ObjCount - 1)) Then
        Exit Sub
    End If

    If (m_ObjCount > 1) Then
        For i = Index To ((m_ObjCount - 1) - 1)
            Set m_QueueObjs(i) = m_QueueObjs(i + 1)
        Next i
        
        ReDim Preserve m_QueueObjs(0 To m_ObjCount - 1)
        
        m_ObjCount = (m_ObjCount - 1)
    Else
        Clear
    End If
End Sub

Public Sub RemoveItemByID(ByVal i As Double)
    Dim j As Long
    
    For j = 0 To m_ObjCount - 1
        If (m_QueueObjs(j).ID = i) Then
            RemoveItem j
            
            Exit Sub
        End If
    Next j
End Sub

Public Sub Clear()
    Dim i As Long

    For i = 0 To m_ObjCount - 1
        Set m_QueueObjs(i) = Nothing
    Next i

    ReDim m_QueueObjs(0)
    
    Set m_QueueObjs(0) = New clsQueueObj
    
    m_ObjCount = 0
    
    KillTimer 0&, QueueTimerID
    
    QueueTimerID = 0
    
    g_BNCSQueue.ClearQueue
End Sub
