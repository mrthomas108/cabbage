Flooper2FilePlayer.csd

Load a user selected sound file into a GEN 01 function table and plays it back using flooper2. 
This file player is best suited for polyphonic playback and is less well suited for the playback of very long sound files .

The sound file can be played back using the Play/Stop button (and the 'Transpose' / 'Speed' buttons to implement pitch/speed change)
 or it can be played back using the MIDI keyboard.

<Cabbage>
form caption("Flooper File Player") size(805,160), colour(0,0,0) pluginID("FlFP")
image                     bounds(  0,  0,805,160), colour(155, 50,  0), outlinecolour("White"), line(3)	; main panel colouration    

filebutton bounds(  5, 10, 80, 25), text("Open File","Open File"), fontcolour("white") channel("filename"), shape("ellipse")
checkbox   bounds(  5, 40, 95, 25), channel("PlayStop"), text("Play/Stop"), colour("yellow"), fontcolour("white")

groupbox   bounds(100, 20,100, 50), plant("looping"), text("Looping Mode"), fontcolour("white"){
combobox   bounds( 10, 25, 80, 20), channel("mode"), items("Forward", "Backward", "Fwd./Bwd."), value(1), fontcolour("white")
}

line       bounds(207, 10,  2, 65), colour("Grey")
                        
label      bounds(302,  4, 43, 8), text("L   O   O   P"), fontcolour("white")
rslider    bounds(210, 15, 60, 60), channel("LoopStart"), range(0, 1, 0),                   colour(165, 60, 10), text("Start"),     fontcolour("white"), trackercolour("DarkBrown")
rslider    bounds(265, 15, 60, 60), channel("LoopEnd"),   range(0, 1, 1),                   colour(165, 60, 10), text("End"),       fontcolour("white"), trackercolour("DarkBrown")
rslider    bounds(320, 15, 60, 60), channel("crossfade"), range(0, 1.00, 0.01,0.5),         colour(165, 60, 10), text("Fade"),      fontcolour("white"), trackercolour("DarkBrown")
rslider    bounds(375, 15, 60, 60), channel("inskip"),    range(0, 1.00, 0),                colour(165, 60, 10), text("inskip"),    fontcolour("white"), trackercolour("DarkBrown")
line       bounds(440, 10,  2, 65), colour("Grey")

label      bounds(475,  4, 53, 8), text("S   P   E   E   D"), fontcolour("white")
rslider    bounds(445, 15, 60, 60), channel("transpose"), range(-24, 24, 0,1,1),            colour(165, 60, 10), text("Transpose"), fontcolour("white"), trackercolour("DarkBrown")
rslider    bounds(500, 15, 60, 60), channel("speed"),     range( 0, 4.00, 1, 0.5),          colour(165, 60, 10), text("Speed"),     fontcolour("white"), trackercolour("DarkBrown")
line       bounds(560, 10,  2, 65), colour("Grey")

label      bounds(576,  4, 90, 8), text("E   N   V   E   L   O   P   E"), fontcolour("white")
rslider    bounds(565, 15, 60, 60), channel("AttTim"),    range(0, 5, 0, 0.5, 0.001),       colour(165, 60, 10), text("Att.Tim"),   fontcolour("white"), trackercolour("DarkBrown")
rslider    bounds(620, 15, 60, 60), channel("RelTim"),    range(0.01, 5, 0.05, 0.5, 0.001), colour(165, 60, 10), text("Rel.Tim"),   fontcolour("white"), trackercolour("DarkBrown")
line       bounds(680, 10,  2, 65), colour("Grey")

label      bounds(702,  4, 80, 8), text("C   O   N   T   R   O   L"), fontcolour("white")
rslider    bounds(685, 15, 60, 60), channel("MidiRef"),   range(0,127,60, 1, 1),            colour(165, 60, 10), text("MIDI Ref."), fontcolour("white"), trackercolour("DarkBrown")
rslider    bounds(740, 15, 60, 60), channel("level"),     range(  0,  3.00, 1, 0.5),        colour(165, 60, 10), text("Level"),     fontcolour("white"), trackercolour("DarkBrown")

keyboard bounds(5, 80, 795, 75)
</Cabbage>

<CsoundSynthesizer>

<CsOptions>
-n -+rtmidi=NULL -M0 -dm0
</CsOptions>

<CsInstruments>

sr = 44100
ksmps = 64
nchnls = 2
0dbfs = 1

		massign	0,3
gichans		init	0
giReady		init	0
gSfilepath	init	""

instr	1
 gkmode		chnget	"mode"
 gkLoopStart	chnget	"LoopStart"
 gkLoopEnd	chnget	"LoopEnd"
 gkLoopEnd	limit	gkLoopEnd,gkLoopStart+0.01,1	; limit loop end to prevent crashes
 gkcrossfade	chnget	"crossfade"
 gkinskip	chnget	"inskip"
 gkPlayStop	chnget	"PlayStop"
 gktranspose	chnget	"transpose"
 gkspeed	chnget	"speed"
 gklevel	chnget	"level"

 gSfilepath	chnget	"filename"
 kNewFileTrg	changed	gSfilepath		; if a new file is loaded generate a trigger
 if kNewFileTrg==1 then				; if a new file has been loaded...
  event	"i",99,0,0				; call instrument to update sample storage function table 
 endif  
 
 ktrig	trigger	gkPlayStop,0.5,0		; if play button changes to 'play', generate a trigger
 schedkwhen	ktrig,0,0,2,0,-1		; start instr 2 playing a held note

 ktrig1	changed	gktranspose			; if 'transpose' button is changed generate a '1' trigger
 ktrig2	changed	gkspeed				; if 'speed' button is changed generate a '1' trigger
 
 if ktrig1==1 then				; if transpose control has been changed...
  chnset	semitone(gktranspose),"speed"	; set speed according to transpose value
 elseif ktrig2==1 then		; if speed control has been changed...
  chnset	log2(gkspeed)*12,"transpose"	; set transpose control according to speed value
 endif

endin



instr	99	; load sound file
 gichans	filenchnls	gSfilepath			; derive the number of channels (mono=1,stereo=2) in the sound file
 gitableL	ftgen	1,0,0,1,gSfilepath,0,0,1
 giFileLen	filelen		gSfilepath			; derive the file duration
 if gichans==2 then
  gitableR	ftgen	2,0,0,1,gSfilepath,0,0,2
 endif
 giReady 	=	1					; if no string has yet been loaded giReady will be zero
endin



instr	2	; sample triggered by 'play/stop' button
 if gkPlayStop==0 then
  turnoff
 endif
 ktrig changed	gkmode
 if ktrig==1 then
  reinit RESTART
 endif
 RESTART:
 if giReady = 1 then						; i.e. if a file has been loaded
  iAttTim	chnget	"AttTim"				; read in widgets
  iRelTim	chnget	"RelTim"
  if iAttTim>0 then						; is amplitude envelope attack time is greater than zero...
   kenv	linsegr	0,iAttTim,1,iRelTim,0				; create an amplitude envelope with an attack, a sustain and a release segment (senses realtime release)
  else
   kenv	linsegr	1,iRelTim,0					; create an amplitude envelope with a sustain and a release segment (senses realtime release)
  endif
  kenv	expcurve	kenv,8					; remap amplitude value with a more natural curve
  aenv	interp		kenv					; interpolate and create a-rate envelope
  kporttime	linseg	0,0.001,0.05				; portamento time function. (Rises quickly from zero to a held value.)
  kspeed	portk	gkspeed,kporttime			; apply portamento smoothing to changes in speed
  klevel	portk	gklevel,kporttime			; apply portamento smoothing to changes in level
  kcrossfade	=	0.01
  istart	=	0
  ifenv		=	0
  iskip		=	0
  if gichans==1 then						; if mono...
   a1	flooper2	klevel,kspeed, gkLoopStart*giFileLen, gkLoopEnd*giFileLen, gkcrossfade, gitableL, i(gkinskip)*giFileLen, i(gkmode)-1, ifenv, iskip
	outs	a1*aenv,a1*aenv					; send mono audio to both outputs 
  elseif gichans==2 then						; otherwise, if stereo...
   a1	flooper2	klevel,kspeed, gkLoopStart*giFileLen, gkLoopEnd*giFileLen, gkcrossfade, gitableL, i(gkinskip)*giFileLen, i(gkmode)-1, ifenv, iskip
   a2	flooper2	klevel,kspeed, gkLoopStart*giFileLen, gkLoopEnd*giFileLen, gkcrossfade, gitableR, i(gkinskip)*giFileLen, i(gkmode)-1, ifenv, iskip
 	outs	a1*aenv,a2*aenv					; send stereo signal to outputs
  endif               
 endif
endin

instr	3	; sample triggered by midi note
 icps	cpsmidi							; read in midi note data as cycles per second
 iamp	ampmidi	1						; read in midi velocity (as a value within the range 0 - 1)
 iMidiRef	chnget	"MidiRef"
/*
 if giReady = 1 then						; i.e. if a file has been loaded
  iAttTim	chnget	"AttTim"				; read in widgets
  iRelTim	chnget	"RelTim"
  if iAttTim>0 then						; is amplitude envelope attack time is greater than zero...
   kenv	linsegr	0,iAttTim,1,iRelTim,0				; create an amplitude envelope with an attack, a sustain and a release segment (senses realtime release)
  else
   kenv	linsegr	1,iRelTim,0					; create an amplitude envelope with a sustain and a release segment (senses realtime release)
  endif
  kenv	expcurve	kenv,8					; remap amplitude value with a more natural curve
  aenv	interp		kenv					; interpolate and create a-rate envelope
  kporttime	linseg	0,0.001,0.05				; portamento time function. (Rises quickly from zero to a held value.)
  ispeed	=	icps/cpsmidinn(iMidiRef)	; derive playback speed from note played in relation to a reference note (MIDI note 60 / middle C)
  klevel	portk	gklevel,kporttime		; apply portamento smoothing to changes in level
  if gichans==1 then						; if mono...
   a1	loscil3	klevel*aenv*iamp,ispeed,gitable,1,i(gkloop)-1,nsamp(gitable)*i(gkLoopStart),nsamp(gitable)*i(gkLoopEnd)	; use a mono loscil3
 	outs	a1,a1						; send mono audio to both outputs 
  elseif gichans==2 then						; otherwise, if stereo...
   a1,a2	loscil3	klevel*aenv*iamp,ispeed,gitable,1,i(gkloop)-1,nsamp(gitable)*i(gkLoopStart),nsamp(gitable)*i(gkLoopEnd)	; use stereo loscil3
 	outs	a1,a2						; send stereo signal to outputs
  endif
 endif
*/
endin
 
</CsInstruments>  

<CsScore>
i 1 0 [60*60*24*7]
</CsScore>

</CsoundSynthesizer>
