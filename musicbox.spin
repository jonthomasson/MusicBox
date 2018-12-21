{
    By: Kwabena W. Agyeman - 9/27/2013
}

CON

    _clkfreq = 80_000_000
    _clkmode = xtal1 + pll16x

    rx = 31
    tx = 30

    lPin = 26
    rPin = 27

    doPin = 22
    clkPin = 23
    diPin = 24
    csPin = 25

    wpPin = -1
    cdPin = -1
CON
    ROWS_PER_FILE = 4 'number of longs it takes to store 1 file name
    MAX_FILES = 300 'limiting to 300 games for now due to memory limits

OBJ

    ser: "FullDuplexSerial.spin"

    wav: "V2-WAV_DACEngine.spin"
    sd: "fsrw" 
    rr: "RealRandom"
VAR
    byte tbuf[14]  
    'long rand
    long file_count
    long files[MAX_FILES * ROWS_PER_FILE] 'byte array to hold index and filename
PUB main | rand

    ser.Start(rx, tx, 0, 115200)
   

    waitcnt((clkfreq * 5) + cnt)
        
    sd.mount(doPin) ' Mount SD card
    sd.opendir    'open root directory for reading
                  '
    repeat while 0 == sd.nextfile(@tbuf)    
        'move tbuf to files. each file takes up 4 rows of files
        'each row can hold 4 bytes (32 bit long / 8bit bytes = 4)
        'since the short file name needs 13 bytes (8(name)+1(dot)+3(extension)+1(zero terminate))
        bytemove(@files[ROWS_PER_FILE*file_count],@tbuf,strsize(@tbuf))
      
        file_count++
    sd.unmount 'unmount the sd card
               '
    'ser.Dec (file_count)
         
    'now we need to get a random file name to pass to wav player
    'ser.Str (@files[ROWS_PER_FILE * 1])
    'repeat 15 - strsize( @files[ROWS_PER_FILE * count2] )     
       
      
    if(wav.begin(lPin, rPin, doPin, clkPin, diPin, csPin, wpPin, cdPin))
        ser.Str(string("Start: Success", 10))

    else
        ser.Str(string("Start: Failure", 10))

    wav.setLeftVolume(2)
    wav.setRightVolume(2)
    
    'start RealRandom
    rr.start 
    'rand := rr.random >> 1 'shifting bits over one to ensure non signed
    rand := (rr.random >> 1)//(file_count) 
    
    rr.stop
    ser.Dec (rand)
    result := \wav.play(@files[ROWS_PER_FILE * rand])
    
    if(wav.playErrorNum)
            ser.Str(string("WAV Error: "))
            ser.Str(result)
            ser.Tx(10)
            
   
        

       
