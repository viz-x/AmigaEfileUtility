MODULE 'dos/dos'
MODULE 'dos/dosextens'
MODULE 'utility/date'

OBJECT afile
  name[80]:CHAR
  size:LONG
  type:LONG
ENDOBJECT

PROC main() HANDLE
  DEF cmd[3]:CHAR
  DEF quit:LONG
  DEF error:LONG
  
  error := 0
  quit := 0
  
  PrintF('---------------------------------\n')
  PrintF('Amiga-E File Utility v1.0\n')
  PrintF('---------------------------------\n')
  PrintF('\n')
  
  WHILE quit = 0
    PrintF('Command [L]ist [V]iew [O]pen [Q]uit: ')
    Input(cmd, 2)
    UpperStr(cmd)
    
    SELECT cmd[0]
    CASE 'L'
      listFiles()
    CASE 'V'
      viewFileInfo()
    CASE 'O'
      openFile()
    CASE 'Q'
      PrintF('\nGoodbye!\n')
      quit := 1
    DEFAULT
      PrintF('\nInvalid command. Try L, V, O or Q.\n')
    ENDSELECT
    
    PrintF('\n')
  ENDWHILE
  
EXCEPT DO
  error := Except()
  IF error <> 0
    PrintF('Error: $\h\n', error)
  ENDIF
ENDPROC

PROC listFiles()
  DEF lock:LONG, fib:PTR TO FileInfoBlock
  DEF buffer[256]:CHAR
  DEF fileCount:LONG, dirCount:LONG
  DEF ioErr:LONG
  
  NEW fib
  
  PrintF('\n--- Directory Listing ---\n')
  
  lock := Lock('', ACCESS_READ)
  IF lock = 0
    PrintF('Cannot lock directory.\n')
    END fib
    RETURN
  ENDIF
  
  -> Start directory scanning
  IF Examine(lock, fib) = FALSE
    PrintF('Cannot examine directory.\n')
    UnLock(lock)
    END fib
    RETURN
  ENDIF
  
  -> Simple while loop with ExNext
  WHILE ExNext(lock, fib) <> 0
    StrCopy(buffer, fib.fib_FileName, ALL)
    
    -> Skip the "." and ".." directory entries
    IF (StrCmp(buffer, '.') = 0) OR (StrCmp(buffer, '..') = 0)
      -> Skip processing for . and ..
    ELSE
      IF fib.fib_DirEntryType > 0
        PrintF('DIR  $\s\n', buffer)
        dirCount++
      ELSE
        PrintF('FILE $\s\n', buffer)
        fileCount++
      ENDIF
    ENDIF
  ENDWHILE
  
  -> Check if we stopped due to error
  ioErr := IoErr()
  IF ioErr <> 0 AND ioErr <> 232  -> ERROR_NO_MORE_ENTRIES
    PrintF('Directory read error: $\d\n', ioErr)
  ENDIF
  
  UnLock(lock)
  
  PrintF('\nTotal: $\d files, $\d directories\n', fileCount, dirCount)
  
  END fib
ENDPROC

PROC getExtension(filename:PTR TO CHAR, extBuf:PTR TO CHAR)
  DEF i:LONG, len:LONG, found:LONG
  
  len := StrLen(filename)
  extBuf[0] := 0
  found := 0
  
  FOR i := len-1 TO 0 STEP -1
    IF filename[i] = '.'
      -> Check if this is not the first character (hidden files)
      IF i > 0
        -> Copy extension
        StrCopy(extBuf, filename + i, ALL)
        found := 1
      ENDIF
      JUMP done
    ENDIF
  ENDFOR
  
done:
  IF found = 0
    extBuf[0] := 0
  ENDIF
ENDPROC

PROC toUpper(str:PTR TO CHAR)
  DEF i:LONG, c:CHAR
  
  i := 0
  WHILE str[i] <> 0
    c := str[i]
    IF c >= 'a' AND c <= 'z'
      str[i] := c - 32
    ENDIF
    i++
  ENDWHILE
ENDPROC

PROC viewFileInfo()
  DEF filename[256]:CHAR
  DEF fib:PTR TO FileInfoBlock
  DEF lock:LONG
  DEF dt:datetime
  DEF dateStr[40]:CHAR
  DEF ext[12]:CHAR
  DEF result:LONG
  DEF extLen:LONG
  
  PrintF('\nEnter filename: ')
  Input(filename, 255)
  
  IF StrLen(filename) = 0
    PrintF('No filename entered.\n')
    RETURN
  ENDIF
  
  NEW fib
  
  lock := Lock(filename, ACCESS_READ)
  IF lock = 0
    PrintF('File not found: $\s\n', filename)
    END fib
    RETURN
  ENDIF
  
  result := Examine(lock, fib)
  IF result = FALSE
    PrintF('Cannot examine file.\n')
    UnLock(lock)
    END fib
    RETURN
  ENDIF
  
  PrintF('\n--- File Information ---\n')
  PrintF('Name: $\s\n', fib.fib_FileName)
  PrintF('Size: $\d bytes\n', fib.fib_Size)
  
  IF fib.fib_DirEntryType > 0
    PrintF('Type: Directory\n')
  ELSE
    PrintF('Type: File\n')
  ENDIF
  
  -> Format date string correctly
  dt.dat_Stamp := fib.fib_Date
  dt.dat_Format := 0  -> DOS format
  dt.dat_Flags := 0
  dt.dat_StrDay := NIL
  dt.dat_StrDate := dateStr
  dt.dat_StrTime := NIL
  
  IF DateToStr(dt) <> NIL
    PrintF('Date: $\s\n', dateStr)
  ELSE
    PrintF('Date: Unknown\n')
  ENDIF
  
  -> Determine file type based on extension
  getExtension(filename, ext)
  IF StrLen(ext) > 0
    -> Convert extension to uppercase for case-insensitive comparison
    toUpper(ext)
    extLen := StrLen(ext)
    
    -> Compare with known extensions
    IF (extLen = 4 AND StrCmp(ext, '.TXT', 4) = 0) OR
       (extLen = 4 AND StrCmp(ext, '.DOC', 4) = 0) OR
       (extLen = 5 AND StrCmp(ext, '.INFO', 5) = 0) OR
       (extLen = 7 AND StrCmp(ext, '.README', 7) = 0) OR
       (extLen = 6 AND StrCmp(ext, '.GUIDE', 6) = 0) OR
       (extLen = 5 AND StrCmp(ext, '.TEXT', 5) = 0)
      PrintF('Format: Text\n')
    ELSEIF (extLen = 4 AND StrCmp(ext, '.EXE', 4) = 0) OR
           (extLen = 7 AND StrCmp(ext, '.BINARY', 7) = 0) OR
           (extLen = 4 AND StrCmp(ext, '.PRG', 4) = 0) OR
           (extLen = 5 AND StrCmp(ext, '.TOOL', 5) = 0)
      PrintF('Format: Binary/Executable\n')
    ELSEIF (extLen = 4 AND StrCmp(ext, '.GIF', 4) = 0) OR
           (extLen = 4 AND StrCmp(ext, '.JPG', 4) = 0) OR
           (extLen = 4 AND StrCmp(ext, '.PNG', 4) = 0) OR
           (extLen = 4 AND StrCmp(ext, '.IFF', 4) = 0) OR
           (extLen = 5 AND StrCmp(ext, '.ILBM', 5) = 0) OR
           (extLen = 4 AND StrCmp(ext, '.HAM', 4) = 0) OR
           (extLen = 4 AND StrCmp(ext, '.BMP', 4) = 0)
      PrintF('Format: Graphics\n')
    ELSEIF (extLen = 4 AND StrCmp(ext, '.MOD', 4) = 0) OR
           (extLen = 4 AND StrCmp(ext, '.WAV', 4) = 0) OR
           (extLen = 4 AND StrCmp(ext, '.VOC', 4) = 0) OR
           (extLen = 5 AND StrCmp(ext, '.8SVX', 5) = 0) OR
           (extLen = 4 AND StrCmp(ext, '.SMP', 4) = 0)
      PrintF('Format: Audio\n')
    ELSEIF (extLen = 4 AND StrCmp(ext, '.LHA', 4) = 0) OR
           (extLen = 4 AND StrCmp(ext, '.LZH', 4) = 0) OR
           (extLen = 4 AND StrCmp(ext, '.ZIP', 4) = 0)
      PrintF('Format: Archive\n')
    ELSE
      PrintF('Format: Unknown\n')
    ENDIF
  ELSE
    PrintF('Format: Unknown (no extension)\n')
  ENDIF
  
  UnLock(lock)
  END fib
ENDPROC

PROC openFile()
  DEF filename[256]:CHAR
  DEF fh:LONG
  DEF buffer[257]:CHAR
  DEF bytesRead:LONG
  DEF lineCount:LONG
  DEF maxLines:LONG
  DEF i:LONG, j:LONG
  DEF eof:LONG
  DEF ioError:LONG
  
  eof := 0
  lineCount := 0
  maxLines := 50
  
  PrintF('\nEnter filename to view: ')
  Input(filename, 255)
  
  IF StrLen(filename) = 0
    PrintF('No filename entered.\n')
    RETURN
  ENDIF
  
  fh := Open(filename, MODE_OLDFILE)
  IF fh = 0
    PrintF('Cannot open file: $\s\n', filename)
    RETURN
  ENDIF
  
  PrintF('\n---- File Preview ----\n')
  
  WHILE (lineCount < maxLines) AND (eof = 0)
    -> Initialize buffer
    FOR i := 0 TO 256
      buffer[i] := 0
    ENDFOR
    
    bytesRead := FGets(fh, buffer, 256)
    IF bytesRead <= 0
      ioError := IoErr()
      IF bytesRead = 0 AND ioError = 0
        eof := 1
      ELSE
        PrintF('Read error: $\d\n', ioError)
        eof := 1
      ENDIF
      JUMP done
    ENDIF
    
    -> Null termination
    IF bytesRead < 256
      buffer[bytesRead] := 0
    ENDIF
    
    -> Remove trailing newline/carriage return
    i := StrLen(buffer)
    IF i > 0
      j := i-1
      WHILE j >= 0 AND (buffer[j] = 10 OR buffer[j] = 13)
        buffer[j] := 0
        j--
      ENDWHILE
    ENDIF
    
    PrintF('$\s\n', buffer)
    lineCount++
  ENDWHILE
  
  IF lineCount = maxLines
    PrintF('\n[...] (file truncated at $\d lines)\n', maxLines)
  ENDIF
  
done:
  Close(fh)
  PrintF('--------------------\n')
ENDPROC
