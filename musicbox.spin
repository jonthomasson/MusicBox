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

    doPin = 0
    clkPin = 1
    diPin = 2
    csPin = 3

    wpPin = -1
    cdPin = -1
    
    wakeup_pin = 5
    
    LEDS = 28
    STRIP_LEN =4                                              
    PIX_BITS  = 24  
CON
    ROWS_PER_FILE = 4 'number of longs it takes to store 1 file name
    MAX_FILES = 300 'max number of songs on sd card

OBJ
    time  : "jm_time_80" 
    ser: "FullDuplexSerial.spin"
    strip : "jm_rgbx_pixel" 'ws2812b driver
    wav: "V2-WAV_DACEngine.spin"
    sd: "fsrw" 
    rr: "RealRandom"
VAR
    byte tbuf[14]  
    word is_awake
    long file_count
    long files[MAX_FILES * ROWS_PER_FILE] 'byte array to hold index and filename
    long  pixbuf1[STRIP_LEN]                                      ' pixel buffers
    long  pixbuf2[STRIP_LEN]
    long  pixbuf3[STRIP_LEN]
PUB main 
    setup
    
    'play_song  
    
    'simple state machine: state 1 = lid open, state 2 = lid closed
    repeat
        if(ina[wakeup_pin] == 1)  'lid has been opened, start cogs, play music etc...
            if(is_awake == 0)
                is_awake := 1
                wake_up
                play_song 
            else
                rainbow(4)
            
        elseif(ina[wakeup_pin] == 0 and is_awake == 1) 'lid has been closed, stop cogs, stop music etc...
            is_awake := 0
            strip.clear
            stop_song
            strip.stop
            sleep
            
pri setup
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
               '
    longfill(@pixbuf1, $20_00_00_00, STRIP_LEN)                   ' prefill buffers
    longfill(@pixbuf2, $00_20_00_00, STRIP_LEN)
    longfill(@pixbuf3, $00_00_20_00, STRIP_LEN) 
    
    'set led strip off
    strip.start_2812b(@pixbuf1, STRIP_LEN, LEDS, 1_0)             ' start pixel driver for WS2812b 
    strip.clear
    time.pause(100)
    strip.stop
    

pri rainbow(ms) | pos, ch

  repeat pos from 0 to 255
    repeat ch from 0 to STRIP_LEN-1
        strip.set(ch, strip.wheelx(256 / STRIP_LEN * ch + pos, $25))   
    time.pause(ms)
    
pri wake_up
    'wake up from low power mode
    clkset($68, 12_000_000)  ' oscillator & pll warmup, RCfast 
    waitcnt(6_000_000+cnt)
    clkset(%0_1_1_01_111,80_000_000) ' set clock
    waitcnt(16_000_000+cnt)
    
    ser.Start(rx, tx, 0, 115200)
    strip.start_2812b(@pixbuf1, STRIP_LEN, LEDS, 1_0)             ' start pixel driver for WS2812b 
    strip.clear
    time.start                                                    ' setup timing & delays
   
    
    waitcnt((clkfreq * 5) + cnt)
         
    
    if(wav.begin(lPin, rPin, doPin, clkPin, diPin, csPin, wpPin, cdPin))
        ser.Str(string("Start: Success", 10))

    else
        ser.Str(string("Start: Failure", 10))

    wav.setLeftVolume(2)
    wav.setRightVolume(2)
    
pri sleep
    
    'ser.Str(string("sleeping...", 10))
    'switch to slowest clock to save power
    clkset(%0_0_0_00_001,20_000) ' RCslow 
    waitcnt(20_000+cnt)
    
pri stop_song | ch
    'stop all cogs
    
    'ser.Stop
    wav.setPause(true)
    wav.overrideSong(true)     
    wav.end  
    

        
pri play_song | rand

    'we need to get a random file name to pass to wav player 
    'start RealRandom
    rand := 0
    rr.start 
    rand := (rr.random >> 1)//(file_count) 'shifting bits over one to ensure non signed
                                           'generate a random number between 0 and file_count
    
    rr.stop
    ser.Dec (rand)
    wav.setPause(false)
    wav.overrideSong(false) 
    result := \wav.play(@files[ROWS_PER_FILE * rand])
    
    if(wav.playErrorNum)
            ser.Str(string("WAV Error: "))
            ser.Str(result)
            ser.Tx(10)
            play_song
            
    'repeat
    '    rainbow(4)
       
