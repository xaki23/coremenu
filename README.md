
this is a works-for-me grade coreboot payload picker

original work was a half-afternoon project.
basicly "lets take a look at libpayload". 

because bayou doesnt build/work at all (seems to need a few years worth of libpayload updates and re-integrating into build), 
seabios has too many drivers for my taste (even when stripped down), 
and cb-grub is a mess i never want to see again.

just tested it builds by copying the dir to a coreboot/payloads/ and running "make" twice.
the resulting .elf has a reasonable size but i didnt test it just now.

the code contains a bazillion of commented out debugprints and other research leftovers.
i have been using the result "in production" for the last months, but never rebuilt it.
it may be interesting to others as an example anyways. 

it doesnt know how to relocate payloads, or to relocate itself out of the way. 
but tries to detect when a payload clashes with itself though. 
(thats what most of the debugprints are about) 
sample code for "relocate self out of the way" would be seabios, but that was one giant linker hack. 
sample code for "relocate a payload while loading" is in FILO or bayou or plain libpayload somewhere.
i ended up just sidestepping the topic by picking some place that didnt collide with my actual payloads in lpcfg ... 

tested + works for loading of ... coreinfo, cros-recovery (which it replaces in my setup), linux kernel (most used), seabios, tint 

license situation unclear since its somewhat futile to track down where the individual parts were copy-pasted from by now.
feedback not involving lawyers welcome.

