<Cabbage>
form caption("GEN20"), size(410, 200), pluginID("gn10"), colour("20,70,170,150")

table bounds(  5,  5, 400, 120), tableNumbers(1), tablecolour("yellow"), identchannel("table1")

combobox bounds(130, 130, 175,20), channel("window"), value(1), text("Hamming","Hanning","Bartlett {Triangle}","Blackman {3-term}","Blackman-Harris {4-term}","Gaussian","Kaiser","Rectangle","Sync.")


hslider  bounds(  5,150,340, 30), text("Option"), channel("opt"), range(0, 10.00, 1, 0.5), textBox(1), trackercolour("yellow"), fontcolour("white")
label    bounds(  3,172,110, 11), text("{Gaussian & Kaiser}"),  FontColour("white")
checkbox bounds(350,158, 50, 13), text("x 100") channel("x100"), colour("yellow"), FontColour("white"),  value(0)

</Cabbage>
                    
<CsoundSynthesizer>

<CsOptions>   
-dm0 -n -+rtmidi=null -M0
</CsOptions>

<CsInstruments>

sr 		= 	44100	; SAMPLE RATE
ksmps 		= 	32	; NUMBER OF AUDIO SAMPLES IN EACH CONTROL CYCLE
nchnls 		= 	2	; NUMBER OF CHANNELS (1=MONO)
0dbfs		=	1	; MAXIMUM AMPLITUDE
			
giwindow	ftgen	1,0,4096,20,1,1,1

instr	1
	; read in widgets
	gkwindow	chnget	"window"
	gkwindow	init	1
	gkopt	chnget	"opt"
	gkopt	init	1
	gkx100	chnget	"x100"
	
	ktrig1	changed	gkwindow
	ktrig2	changed	gkopt,gkx100
	if ktrig1==1 || ( (ktrig2==1&&(gkwindow==6||gkwindow==7))) then
	 reinit UPDATE
	endif
	UPDATE:
	 giwindow	ftgen	1,0,ftlen(giwindow),20,i(gkwindow),1,i(gkopt)* ((i(gkx100)*99)+1)
	rireturn
	if ktrig1==1||ktrig2==1 then
	 chnset	"tablenumber(1)", "table1"	; update table display	
	endif
	aenv	poscil	0.05,1,giwindow
	asig	vco2	1,440,4,0.5
	asig	*=		aenv
			outs	asig,asig
endin

</CsInstruments>

<CsScore>
i 1 0 [3600*24*7]
e
</CsScore>

</CsoundSynthesizer>
