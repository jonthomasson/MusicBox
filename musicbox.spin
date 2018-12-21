{
    By: Jon Thomasson - 12/21/2018
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
    
    wakeup_pin = 28
CON
    ROWS_PER_FILE = 4 'number of longs it takes to store 1 file name
    MAX_FILES = 300 'max number of songs on sd card

OBJ

    ser: "FullDuplexSerial.spin"

    wav: "V2-WAV_DACEngine.spin"
    sd: "fsrw" 
    rr: "RealRandom"
VAR
    byte tbuf[14]  
    word is_awake
    long file_count
    long files[MAX_FILES * ROWS_PER_FILE] 'byte array to hold index and filename
PUB main 
    dira[wakeup_pin]~ 'set wakeup_pin to input
    is_awake := 0            
    
    'load songs into array so that they can be randomized and accessed later without mounting the sd card
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
    
    'simple state machine: state 1 = lid open, state 2 = lid closed
    repeat
        if(ina[wakeup_pin] == 1 and is_awake == 0)  'lid has been opened, start cogs, play music etc...
            is_awake := 1
            
            play_song
        elseif(ina[wakeup_pin] == 0 and is_awake == 1) 'lid has been closed, stop cogs, stop music etc...
            is_awake := 0
            
            stop_song
            
            
pri stop_song
    'stop all cogs
    ser.Stop
    wav.setPause(true)
    wav.overrideSong(true)     
    wav.end  
    
    'switch to slowest clock to save power
    clkset(%0_0_0_00_001,20_000) ' RCslow 
    waitcnt(20_000+cnt)
        
pri play_song | rand
    'wake up from low power mode
    clkset($68, 12_000_000)  ' oscillator & pll warmup, RCfast 
    waitcnt(6_000_000+cnt)
    clkset(%0_1_1_01_111,80_000_000) ' set clock
    waitcnt(16_000_000+cnt)
  
    ser.Start(rx, tx, 0, 115200)
   
    rand := 0
    waitcnt((clkfreq * 5) + cnt)
         
    'now we need to get a random file name to pass to wav player 
    
    if(wav.begin(lPin, rPin, doPin, clkPin, diPin, csPin, wpPin, cdPin))
        ser.Str(string("Start: Success", 10))

    else
        ser.Str(string("Start: Failure", 10))

    wav.setLeftVolume(2)
    wav.setRightVolume(2)
    
    'start RealRandom
    rr.start 
    rand := (rr.random >> 1)//(file_count) 'shifting bits over one to ensure non signed
                                           'generate a random number between 0 and file_count
    
    rr.stop
    'ser.Dec (rand)
    result := \wav.play(@files[ROWS_PER_FILE * rand])
    
    if(wav.playErrorNum)
            ser.Str(string("WAV Error: "))
            ser.Str(result)
            ser.Tx(10)
       
