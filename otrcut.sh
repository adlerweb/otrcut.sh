#!/bin/bash

#Dieses Script schneidet Filme/Serien von http://www.onlinetvrecorder.de anhand der Schnittlisten von
#http://www.cutlist.at.
#Dies geschieht entweder durch avidemux oder avisplit/avimerge.
#Avidemux schneidet im Gegensatz zu avisplit/avimerge keyframe-genau.
#avisplit/avimerge ist Bestandteil von transcode, avidemux muss separat installiert werden.
#
#Dieses Script darf frei verändert und weitergegeben werden.
#
#Author: Daniel Siegmanski
#Homepage: http://www.siggimania4u.de
#OtrCut Download: http://otrcut.siggimania4u.de

#Hier werden verschiedene Variablen definiert.
version=20090816	#Die Version von OtrCut, Format: yyyymmdd, yyyy=Jahr mm=Monat dd=Tag
LocalCutlistOkay=no	#Ist die lokale Cutlist vorhanden?
input=()		#Eingabedatei/en
CutProg=""		#Zu verwendendes Schneideprogramm
LocalCutlistName=""	#Name der lokalen Cutlist
format=""		#Um welches Format handelt es sich? AVI, HQ, mp4
cutlistWithError=""	#Cutlists die, einen Fehler haben
delete=no
continue=0
aspect=43		#Standard-Seitenverhältnis
rot="\033[22;31m"	#Rote Schrift
gruen="\033[22;32m"	#Grüne Schrift
gelb="\033[22;33m"	#Gelbe Schrift
blau="\033[22;34m"	#Blaue Schrift
normal="\033[0m"	#Normale Schrift

#Dieses Variablen werden gesetzt, sofern aber ein Config-File besteht wieder überschrieben
UseLocalCutlist=no	#Lokale Cutlists verwenden?
HaltByErrors=no		#Bei Fehlern anhalten?
toprated=no		#Die Cutlist mit der besten User-Bewertung benutzen?
UseAvidemux=yes		#Avidemux verwenden?
ShowAllCutlists=yes	#Auswahl mehrerer Cutlists anzeigen?
tmp="/tmp/otrcut"	#Zu verwendender Tmp-Ordner, in diesem Ordner wird dann noch ein Ordner "otrcut" erstellt.
overwrite=no		#Bereits vorhandene Dateien überschreiben
output=cut		#Ausgabeordner
bewertung=no		#Bewertungsfunktion benutzen
verbose=no		#Ausführliche Ausgabe von avidemux bzw. avisplit/avimerge anzeigen
play=no			#Datei nach dem Schneiden wiedergeben
warn=yes		#Warnung bezüglich der Löschung von $tmp ausgeben
user=otrcut		#Benutzer der zum Bewerten benutzt wird
player=mplayer		#Mit diesem Player wird das Video wiedergegeben sofern $play auf yes steht
smart=yes		#Force-Smart für avidemux verwenden
vidcodec=copy		#Input-Video nur kopieren.
personal=no		#Persönliche URL von cutlist.at zum Bewerten benutzen
ad_version=new		#New= Avidemux >=2.5, Old= Avidemux <=2.4
copy=no			#Wenn $toprated=yes, und keine Cutlist gefunden wird, $film nach $output kopieren

#Diese Variablen werden vom Benutzer gesetzt.
#Sie sind für die Verwendung des Decoders gedacht.
email="" #Die EMail-Adresse mit der Sie bei OTR registriert sind
password="" #Das Passwort mit dem Sie sich bei OTR einloggen
decoder="otrdecoder" #Pfad zum decoder. Z.B. /home/benutzer/bin/otrdecoder

#Diese Variablen werden vom Benutzer gesetzt.
personalurl=""	#Die persönliche URL von cutlist.at

if [ -f ~/.otrcut ]; then
	source ~/.otrcut
else
	echo "Keine Config-Datei gefunden, benutze Standardwerte."
fi
	
#Diese Funktion gibt die Hilfe aus
function help ()
{
cat <<HELP
OtrCut Version: $version

Dieses Script schneidet OTR-Dateien anhand der Cutlist von http://cutlist.at.
Es können entweder die Tools avidemux oder avisplit/avimerge benutzt werden.
Avidemux kann im Gegensatz zu avisplit auch zwischen Keyframes schneiden.
Hier die Anwendung:

$0 [optionen] -i film.mpg.avi

Optionen:

-i, --input [arg]	Input Datei/Dateien (kann mehrfach benutzt werden um mehrere Dateien zu schneiden)

-a, --avisplit		Avisplit und avimerge anstelle von avidemux verwenden

-e, --error		Bei Fehlern das Script beenden

--tmp [arg]		TMP-Ordner angeben (Standard: /tmp/), In diesem Ordner wird noch ein Ordner "otrcut" angelegt, ACHTUNG: ALLE Daten in \$tmp werden gelöscht!!!

-l, --local 		Lokale Cutlists verwenden (Cutlists werden im aktuellen Verzeichnis gesucht)

--delete		Quellvideo nach Schneidevorgang löschen ACHTUNG: Falls es sich bei der Quelle um ein OtrKey handelt wird dies auch gelöscht!!!

-o, --output [arg]	Ausgabeordner wählen (Standard "./cut")

-ow, --overwrite	Schon existierende Ausgabedateien überschreiben

-b, --bewertung		Bewertungsfunktion aktivieren

-p, --play		Zusammen mit "-b, --bewertung" einsetzbar, startet vor dem Bewerten das Video in einem Videoplayer (Wird in der Variablen \$player definiert)

-w, --warn		Warnung bezüglich Löschung aller Dateien in \$tmp unterdrücken

--toprated		Verwendet die best bewertetste Cutlist

-v, --verbose		Ausführliche Ausgabe von avidemux bzw. avimerge/avisplit aktivieren

--nosmart		So wird das --force-smart-Argument für avidemux abgeschaltet.

--personal		Die persönliche ID von cutlist.at zum Bewerten benutzen

-av, --avidemux		Bei Verwendung von Avidemux <=2.4 muss diese Schalter gesetzt werden.

-c, --copy		Wenn $toprated=yes, und keine Cutlist gefunden wird, $film nach $output kopieren

--vcodec [arg]          Videocodec (avidemux) spezifizieren. Wenn nicht gesetzt, dann "copy". Mögliche Elemente für [arg]: Divx/Xvid/FFmpeg4/VCD/SVCD/DVD/XVCD/XSVCD/COPY

-u, --update		Nach einer neuen Version von OtrCut suchen

-h, --help		Diese Hilfe ^^

Author: Daniel Siegmanski
Homepage: http://www.siggimania4u.de
Cutlists: http://www.cutlist.de, http://www.cutlist.at

Danke an MKay für das Aspect-Ratio-Script
FPS-Script/HD-Funktion: Florian Knodt <www.adlerweb.info>

HELP
exit 0
}

#Diese Funktion sucht nach einer neuen Version von OtrCut
function update ()
{
online_version=$(wget -q -O - http://otrcut.siggimania4u.de/version | tr -d "\r")

if [ "$online_version" -gt "$version" ]; then
	echo -e "${blau}Es ist eine neue Version verfügbar.${normal}"
	echo -e "${blau}Verwendete Version: $version ${normal}"
	echo -e "${blau}Aktuelle Version: $online_version ${normal}"
	echo "Die neue Version kann unter \"http://otrcut.siggimania4u.de\" heruntergeladen werden."
else
	echo -e "${gelb}Es wurde keine neuere Version gefunden.${normal}"
fi

exit 0
}

#Hier werden die übergebenen Option ausgewertet
while [ ! -z "$1" ]; do
	case $1 in
		-i | --input )	input=("${input[@]}" "$2")
				shift ;;
		-a | --avisplit )	UseAvidemux=no ;;
		-e | --error )	HaltByErrors=yes ;;
		-d | --decode )	decode=yes ;;
		--delete )	delete=yes ;;
		-l | --local )	UseLocalCutlist=yes ;;
		-t | --tmp )	tmp=$2
				shift ;;
		-o | --output )	output=$2
				shift ;;
		-ow | --overwrite )	overwrite=yes ;;
		-v | --verbose )	verbose=yes ;;
		-p | --play )	play=yes ;;
		-b | --bewerten)	bewertung=yes ;;
		-w | --warn )	warn=no ;;
		-c | --copy )	copy=yes ;;
		--personal )	personal=yes ;;
		--toprated )	toprated=yes ;;
		--nosmart )	smart=no ;;
		--vcodec )      vidcodec="$2"
                                shift;;
		-av | --avidemux ) ad_version=old ;;
		-u | --update )	update ;;
		-h | --help )	help ;;
	esac
	shift
done

#Diese Funktion gibt die Warnung bezüglich der Löschung von $tmp aus
function warnung ()
{
if [ "$warn" == "yes" ]; then
	echo -e "${rot}"
	echo "ACHTUNG!!!"
	echo "Das Script wird alle Dateien in $tmp/otrcut löschen!"
	echo "Sie haben 5 Sekunden um das Script über STRG+C abzubrechen"
	
	for (( I=5; I >= 1 ; I-- )); do
		echo -n "$I "
		sleep 1
	done
	echo -e "${normal}"
	echo ""
	echo ""
fi
}

#Diese Funktion gibt einen Hinweis zur Dateinamensübergabe aus
function datei ()
{
echo -e "${gelb}"
echo "ACHTUNG!!!"
echo "Die Eingabedateien müssen entweder ohne führende Verzeichnise "
echo "(z.B. datei.avi, nur wenn Datei im aktuellen Verzeichnis!) oder"
echo "mit dem KOMPLETTEN Pfad (z.B. /home/user/datei.avi) angegeben werden!"
echo -e "${normal}"

sleep 2
echo ""
echo ""
}

#Diese Funktion überprüft verschiedene Einstellungen
function test ()
{
#Hier wird überprüft ob eine Eingabedatei angegeben ist
if [ -z "$i" ]; then		
    echo "${rot}Es wurde keine Eingabedatei angegeben!${normal}"
    exit 1
else
    #Überprüfe ob angegebene Datei existiert
    if [ ! -f "$i" ]; then
        echo -e "${rot}Eingabedatei nicht gefunden!${normal}"
        exit 1
    fi
fi

#Hier wird überprüft ob die Option -p, --play richtig gesetzt wurde
if [ "$play" == "yes" ] && [ "$bewertung" == "no" ]; then
	echo -e "${rot}\"Play\" kann nur in Verbindung mit \"Bewertung\" benutzt werden.${normal}"
	exit 1
fi

#Hier wird überprüft ob der Standard-Ausgabeordner verwendet werden soll.
#Wenn ja, wird überprüft ob er verfügbar ist, wenn nicht wird er erstellt.
#Wurde ein alternativer Ausgabeordner gewählt, wird geprüft ob er vorhanden ist.
#Ist er nicht vorhanden wird gefragt ob er erstellt werden soll.
if [ "$output" == "cut" ]; then
	if [ ! -d "cut" ]; then
		if [ -w $PWD ]; then
			mkdir cut
			echo "Verwende $PWD/cut als Ausgabeordner"
		else
			echo -e "${rot}Sie haben keine Schreibrechte im aktuellen Verzeichnis ($PWD).${normal}"
			exit 1
		fi
	fi
else
	if [ -d "$output" ] && [ -w "$output" ]; then
		echo "Verwende $output als Ausgabeordner."
	elif [ -d "$output" ] && [ ! -w "$output" ]; then
		echo -e "${rot}Sie haben keine Schreibrechte in $output.${normal}"
		exit 1
	else
		echo -e "${gelb}Das Verzeichnis $output wurde nicht gefunden, soll er erstellt werden? [y|n]${normal}"
		read OUTPUT
		while [ "$OUTPUT" == "" ] || [ ! "$OUTPUT" == "y" ] && [ ! "$OUTPUT" == "n" ]; do #Bei falscher Eingabe
			echo -e "${gelb}Falsche Eingabe, bitte nochmal:${normal}"
			read OUTPUT
		done
		if [ "$OUTPUT" == "n" ]; then	#Wenn der Benutzer nein "sagt"
			echo "Ausgabeverzeichnis \"$output\" soll nicht erstellt werden."
			exit 1
		elif [ "$OUTPUT" == "y" ]; then	#Wenn der Benutzer ja "sagt"
			echo -n "Erstelle Ordner $output -->"
			mkdir "$output"
			if [ -d "$output" ]; then
				echo -e "${gruen}okay${normal}"
			else
				echo -e "${rot}false${normal}"
				exit 1
			fi
		fi
	fi
fi

#Hier wird überprüft ob der Standard-Tmpordner verwendet werden soll.
#Wenn ja, wird überprüft ob er verfügbar ist, wenn nicht wird er erstellt.
#Wurde ein alternativer Tmpordner gewählt, wird geprüft ob er vorhanden ist.
#Ist er nicht vorhanden wird gefragt ob er erstellt werden soll.
if [ "$tmp" == "/tmp/otrcut" ]; then
	if [ ! -d "/tmp/otrcut" ]; then
		if [ -w /tmp ]; then
			mkdir "/tmp/otrcut"
			echo "Verwende $tmp als Ausgabeordner"
			#tmp="$tmp/otrcut"
		else
			echo -e "${rot}Sie haben keine Schreibrechte in /tmp/ ${end}"
			exit 1
		fi
	fi
else
	if [ -d "$tmp" ] && [ -w "$tmp" ]; then
		mkdir "$tmp/otrcut"
		echo "Verwende $tmp/otrcut als Ausgabeordner."
		tmp="$tmp/otrcut"
	elif [ -d "$tmp" ] && [ ! -w "$tmp" ]; then
		echo -e "${rot}Sie haben keine Schreibrechte in $tmp!${end}"
	else
		echo -e "${gelb}$tmp wurde nicht gefunden, soll er erstellt werden? [y|n]${end}"
		read TMP	#Lesen der Benutzereingabe nach $TMP
		while [ "$TMP" == "" ] || [ ! "$TMP" == "y" ] && [ ! "$TMP" == "n" ]; do	#Bei falscher Eingabe	
			echo -e "${gelb}Falsche Eingabe, bitte nochmal:${end}" 
			read TMP	#Lesen der Benutzereingabe nach $TMP
		done
		if [ $TMP == n ]; then	#Wenn der Benutzer nein "sagt"
			echo "Tempverzeichnis \"$tmp\" soll nicht erstellt werden."
			exit 1
		elif [ $TMP == y ]; then	#Wenn der Benutzer ja "sagt"
			echo -n "Erstelle Ordner $tmp --> "
			mkdir "$tmp/otrcut"
			if [ -d "$tmp/otrcut" ]; then
				echo -e "${gruen}okay${end}"
				tmp="$tmp/otrcut"
			else
				echo -e "${rot}false${end}"
				exit 1
			fi
		fi
	fi
fi
}

#Diese Funktion überprüft ob avidemux installiert ist
function software ()
{
if [ "$UseAvidemux" == "yes" ]; then
	for s in avidemux2_cli avidemux2_qt4 avidemux2_gtk avidemux2 avidemux; do
		if [ -z $CutProg ]; then
			echo -n "Überprüfe ob $s installiert ist --> "
			if type -t $s >> /dev/null; then
				echo -e "${gruen}okay${normal}"
				CutProg="$s"
			else
				echo -e "${rot}false${normal}"
			fi
		fi
	done
	if [ -z $CutProg ]; then
		echo -e "${rot}Bitte installieren sie avidemux, oder verwenden sie die Optione \"-a\"!${normal}"
		exit 1
	fi
fi

#Hier wird überprüft ob avisplit und avimerge installiert sind
if [ "$UseAvidemux" == "no" ]; then
	for p in avisplit avimerge; do
		echo -n "Überprüfe ob $p installiert ist --> "
		if type -t $p >> /dev/null; then
			echo -e "${gruen}okay${normal}"
			CutProg="avisplit"
		else
			echo -e "${rot}false${normal}"
			echo -e "${gelb}Installieren Sie transcode!${normal}"
			exit 1
		fi
	done
fi

#Hier wird überprüft ob date zum umrechnen der Zeit benutzt werden kann
echo -n "Überprüfe welche Methode zum Umrechnen der Zeit benutzt wird --> "
date_var=$(date -u -d @120 +%T)
if [ "$date_var" == "00:02:00" ]; then
	echo -e "${blau}date${normal}"
	date_okay=yes
else
	echo -e "${gelb}intern${normal}"
	date_okay=no
fi

#Hier wird überprüft ob der richtige Pfad zum Decoder angegeben wurde
if [ "$decoded" == "yes" ]; then
	echo -n "Überprüfe ob der Decoder-Pfad richtig gesetzt wurde --> "
	if $decoder -v >> /dev/null; then
		echo -e "${gruen}okay${normal}"
	else
		echo -e "${rot}false${normal}"
		exit 1
	fi
if [ "$email" == "" ]; then
	echo -e "${rot}EMail-Adresse wurde nicht gesetzt.${normal}"
	exit 1
fi
if [ "$password" == "" ]; then
	echo -e "${rot}Passwort wurde nicht gesetzt.${normal}"
	exit 1
fi
fi
}

#Diese Funktion definiert den Cutlist- und Dateinamen und üperprüft um welches Dateiformat es sich handelt
function name ()
{
film=$i	#Der komplette Filmname und gegebenfalls der Pfad
film_ohne_anfang=$i
#Für Avidemux <=2.5 muss der komplette Pfad angegeben werden
if [ "$ad_version" == "new" ]; then
	film_var=${film#/} 
	output_var=${output#/}
	if [ "$film" == "$film_var" ]; then
		film_new_ad="$PWD/$film"
	else
		film_new_ad="$film"
	fi
	if [ "$output" == "$output_var" ]; then
		output="$PWD/$output"
	fi
fi
if [ "$decoded" == "yes" ]; then
	film_ohne_anfang="${film_ohne_anfang%%.otrkey}"
	film_ohne_anfang="${film_ohne_anfang##*/}"
	film="$film_ohne_anfang"
fi
CUTLIST=`basename "$film"`	#Filmname ohne Pfad
echo -n "Überprüfe um welches Aufnahmeformat es sich handelt --> "
if echo "$film_ohne_anfang" | grep -q ".HQ."; then	#Wenn es sich um eine "HQ" Aufnahme handelt
	film_ohne_ende=${film%%.mpg.HQ.avi}	#Filmname ohne Dateiendung
	CUTLIST=${CUTLIST/.avi/}.cutlist	#Der lokale Cutlistname
	format=hq
	echo -e "${blau}HQ${normal}"
elif echo "$film_ohne_anfang" | grep -q ".mp4"; then	#Wenn es sich um eine "mp4" Aufnahme handelt
	film_ohne_ende=${film%%.mpg.mp4}	#Filmname ohne Dateiendung
	format=mp4
	CUTLIST=${CUTLIST/.mp4/}.cutlist	#Der lokale Cutlistname
	echo -e "${blau}mp4${normal}"
else
	film_ohne_ende=${film%%.mpg.avi}	#Filmename ohne Dateiendung
	format=avi
	CUTLIST=${CUTLIST/.avi/}.cutlist	#Der lokale Cutlistname
	echo -e "${blau}avi${normal}"
fi

if echo "$film" | grep / >> /dev/null; then	#Wenn der Dateiname einen Pfad enthält
	film_ohne_anfang=${film##*/}	#Filmname ohne Pfad
	if echo "$film_ohne_anfang" | grep -q ".HQ."; then	#Wenn es sich um eine "HQ" Aufnahme handelt
		film_ohne_ende=${film_ohne_anfang%%.mpg.HQ.avi}
		format=hq
	elif echo "$film_ohne_anfang" | grep -q ".mp4"; then	#Wenn es sich um eine "mp4" Aufnahme handelt
		film_ohne_ende=${film_ohne_anfang%%.mpg.mp4}
		format=mp4
	else
		film_ohne_ende=${film_ohne_anfang%%.mpg.avi}
		format=avi
	fi
fi

if echo "$film_ohne_anfang" | grep -q ".HQ."; then
   outputfile="$output/$film_ohne_ende.HQ-cut.avi"
elif echo "$film_ohne_anfang" | grep -q ".mp4"; then
   outputfile="$output/$film_ohne_ende-cut.mp4"
else
   outputfile="$output/$film_ohne_ende-cut.avi"
fi
}

#In dieser Funktion wir die lokale Cutlist überprüft
function local ()
{
local_cutlists=$(ls *.cutlist)	#Variable mit allen Cutlists in $PWD
filesize=$(ls -l "$film" | awk '{ print $5 }') #Dateigröße des Filmes
let goodCount=0	#Passende Cutlists
let arraylocal=1	#Nummer des Arrays
for f in $local_cutlists; do
	echo -n "Überprüfe ob eine der gefundenen Cutlists zum Film passt --> "
	if [ -z $f ]; then
		echo -e "${rot}Keine Cutlist gefunden!${normal}"
		if [ "$HaltByErrors" == "yes" ]; then
			exit 1
		else
			vorhanden=no
			continue=1
		fi
	fi

	OriginalFileSize=$(cat $f | grep OriginalFileSizeBytes | cut -d"=" -f2 | tr -d "\r")	#Dateigröße des Films

	if cat $f | grep -q "$film"; then	#Wenn der Dateiname mit ApplyToFile übereinstimmt
		echo -e -n "${blau}ApplyToFile ${normal}"
		ApplyToFile=yes	
		vorhanden=yes
	fi
	if [ "$OriginalFileSize" == "$filesize" ]; then	#Wenn die Dateigröße mit OriginalFileSizeBytes übereinstimmt
		echo -e -n "${blau}OriginalFileSizeBytes${normal}"
		OriginalFileSizeBytes=yes 
		vorhanden=yes
	fi
	if [ "$vorhanden" == "yes" ]; then	#Wenn eine passende Cutlist vorhanden ist
		let goodCount++
		namelocal[$arraylocal]="$f"
		#echo $f
		#echo ${namelocal[$arrylocal]}
		let arraylocal++
		continue=0
	else
		echo -e "${rot}false${normal}"
	fi		
done

if [ "$goodCount" -eq 1 ]; then	#Wenn nur eine Cutlist gefunden wurde
	echo "Es wurde eine passende Cutlist gefunden. Diese wird nun verwendet."
	CUTLIST="$f"
	cp "$CUTLIST" "$tmp"
elif [ "$goodCount" -gt 1 ]; then	#Wenn mehrere Cutlists gefunden wurden
	echo "Es wurden $goodCount Cutlists gefunden. Bitte wählen Sie aus:"
	echo ""
	let number=1
	for (( i=1; i <= $goodCount ; i++ )); do
		
		echo "$number: ${namelocal[$number]}"
		let number++
	done
	echo -n "Bitte die Nummer der zu verwendenden Cutlist eingeben:"
	read NUMBER
	while [ "$NUMBER" -gt "$goodCount" ]; do
		echo "${rot}false. Noch mal:${normal}"
		read NUMBER
	done
	echo "Verwende ${namelocal[$NUMBER]} als Cutlist."
	CUTLIST=$namelocal[$NUMBER]
	cp "$CUTLIST" "$tmp"
	vorhanden=yes
fi
}

#In dieser Funktion wird versucht eine Cutlist aus den Internet zu laden
function load ()
{
#In dieser Funktion wird geprüft, ob die Cutlist okay ist
function test_cutlist ()
{
let cutlist_size=$(ls -l "$tmp/$CUTLIST" | awk '{ print $5 }')
if [ "$cutlist_size" -lt "100" ]; then
	cutlist_okay=no
	rm -rf "$TMP/$CUTLIST"
else
	cutlist_okay=yes
fi
}

if [ "$personal" == "yes" ]; then
	server=$personalurl
else
	server="http://cutlist.at/"
fi

#echo $server

echo -e "Bearbeite folgende Datei: ${blau}$film${normal}"
sleep 1
if [ "$decoded" == "yes" ]; then
	filesize=$(ls -l "$output/$film" | awk '{ print $5 }')
else
	filesize=$(ls -l "$film" | awk '{ print $5 }')
fi
#echo $filesize
echo -n "Führe Suchanfrage bei \"cutlist.at\" durch ---> "
wget -q -O "$tmp/search.xml" "${server}getxml.php?version=0.9.8.0&ofsb=$filesize" &&
if grep -q '<id>' "$tmp/search.xml"; then
	echo -e "${gruen}okay${normal}"
else
	echo -e "${rot}false${normal}"
	if [ "$HaltByErrors" == "yes" ]; then
		exit 1
	else
		continue=1
	fi
fi

#Hier wird die Suchanfrage überprüft
if [ "$continue" == "1" ]; then
	echo -e "${rot}Es wurden keine Cutlists auf cutlist.at gefunden.${normal}"
	if [ "$HaltByErrors" == "yes" ]; then
		exit 1
	elif [ "$toprated" == "no" ] && [ "$copy" == "no" ]; then
		continue=1
		echo -e "${blau}Soll \"$film\" in den Ausgabeordner kopiert erden? [y|n]${normal}"
		read COPY
		while [ "$COPY" == "" ] || [ ! "$COPY" == "y" ] && [ ! "$COPY" == "n" ]; do #Bei falscher Eingabe
			echo -e "${gelb}Falsche Eingabe, bitte nochmal:${normal}"
			read COPY
		done
		if [ "$COPY" == "n" ]; then	#Wenn der Benutzer nein "sagt"
			echo "Datei wird nicht kopiert."
		elif [ "$COPY" == "y" ]; then	#Wenn der Benutzer ja "sagt"
			echo "Datei wird in den Ausgabeordner kopiert."
			cp "$film" "$output/"
		fi
	elif [ "$copy" == "yes" ]; then
		echo "Datei wird in den Ausgabeordner kopiert."
		cp "$film" "$output/"
	fi
else
	if [ "$schon_mal_angezeigt" == "" ]; then
		echo -e "${blau}Cutlist/s gefunden.${normal}"
		echo ""
		echo "Es wurden folgende Cutlists gefunden:"
		schon_mal_angezeigt=yes
		let array=0
	fi
	cutlist_anzahl=$(grep -c '/cutlist' "$tmp/search.xml" | tr -d "\r") #Anzahl der gefundenen Cutlists
	let cutlist_anzahl
	if [ "$cutlist_anzahl" -ge "1" ] && [ "$continue" == "0" ]; then #Wenn mehrere Cutlists gefunden wurden
		echo ""
		let tail=1
		while [ "$cutlist_anzahl" -gt "0" ]; do
			#Name der Cutlist
			name[$array]=$(grep "<name>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			#Author der Cutlist
			author[$array]=$(grep "<author>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			#Bewertung des Authors
			ratingbyauthor[$array]=$(grep "<ratingbyauthor>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			#Bewertung der User
			rating[$array]=$(grep "<rating>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			#Kommentar des Authors
			comment[$array]=$(grep "<usercomment>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			#ID der Cutlist
			ID[$array]=$(grep "<id>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			#Anzahl der Bewertungen
			ratingcount[$array]=$(grep "<ratingcount>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			#Cutangaben in Sekunden
			cutinseconds[$array]=$(grep "<withtime>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			#Cutangaben in Frames (besser)
			cutinframes[$array]=$(grep "<withframes>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			#Filename der Cutlist
			filename[$array]=$(grep "<filename>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")

			if [ "$toprated" == "no" ]; then #Wenn --toprated nicht gesetzt ist
				if echo $cutlistWithError | grep -q "${ID[$array]}"; then #Wenn Fehler gesetzt ist z.B. EPG-Error oder MissingBeginning
					echo -ne "${rot}"
				fi
				echo -n "[$array]"
				echo "  Name: ${name[$array]}"
				echo "     Author: ${author[$array]}"
				echo "     Rating by Author: ${ratingbyauthor[$array]}"
				if [ -z "$cutlistWithError" ]; then
					echo -ne "${gruen}"
				fi
				echo "     Rating by Users: ${rating[$array]} @ ${ratingcount[$array]} Users"
				if [ -z "$cutlistWithError" ]; then
					echo -ne "${normal}"
				fi
				if [ "${cutinframes[$array]}" == "1" ]; then
					echo "     Cutangabe: Als Frames"
				fi
				if [ "${cutinseconds[$array]}" == "1" ] && [ ! "${cutinframes[$array]}" == "1" ]; then
					echo "     Cutangabe: Als Zeit"
				fi
				echo "     Kommentar: ${comment[$array]}"
				echo "     Filename: ${filename[$array]}"
				echo "     ID: ${ID[$array]}"
				#echo "     Server: ${server[$array]}"
				echo ""
				if echo $cutlistWithError | grep -q "${ID[$array]}"; then #Wenn Fehler gesetzt ist z.B. EPG-Error oder MissingBeginning
					echo -ne "${normal}"
				fi
			fi
			
			let tail++
			let cutlist_anzahl--
			let array++
			array1=array
		done

		if [ "$toprated" == "yes" ]; then # Wenn --toprated gesetzt wurde
			if [ "$angezeigt" == "" ]; then
				echo "Lade die Cutlist mit der besten User-Bewertung herunter."
				angezeigt=yes
			fi
			let array1--
			while [ $array1 -ge 0 ]; do
				rating1[$array1]=${rating[$array1]}	
				if [ "${rating1[$array1]}" == "" ]; then	#Wenn keine Benutzerwertung abgegeben wurde
					rating1[$array1]="0.00"			#Schreibe 0.00 als Bewertung
				fi
	      		
				rating1[$array1]=$(echo ${rating1[$array1]} | sed 's/\.//g')	#Entferne den Dezimalpunkt aus der Bewertung. 4.50 wird zu 450
	      			#echo "Rating ohne Komma: ${rating1[$array1]}"
	      			let array1--
	   		done
			numvalues=${#rating1[@]}	#Anzahl der Arrays
           		for (( i=0; i < numvalues; i++ )); do
      				lowest=$i
	      			for (( j=i; j < numvalues; j++ )); do
					if [ ${rating1[j]} -ge ${rating1[$lowest]} ]; then
						lowest=$j
					fi
      				done	
	      	
				temp=${rating1[i]}
      				rating1[i]=${rating1[lowest]}
      				rating1[lowest]=$temp
       			done
          		bigest=${rating1[0]}

           		beste_bewertung=${bigest%%??}	#Die beste Wertung ohne Dezimalpunkt
           		beste_bewertung_punkt=$beste_bewertung.${bigest##?}	#Die beste Wertung mit Dezimalpunkt

		fi
	fi
fi

if [ "$toprated" == "yes" ] && [ "$continue" == "0" ]; then
	bereits_toprated=no
	echo "Die beste Bewertung ist: $beste_bewertung"
	bereits_toprated=yes	
	
	if [ "$beste_bewertung" == "0" ]; then
		beste_bewertung="</rating>"
	fi

	cutlist_nummer=$(grep "<rating>" "$tmp/search.xml" | grep -n "<rating>$beste_bewertung" | cut -d: -f1 | head -n1)
	id=$(grep "<id>" "$tmp/search.xml" | head -n$cutlist_nummer | tail -n1 | cut -d">" -f2 | cut -d"<" -f1) #ID der best bewertetsten Cutlist
	let num=$cutlist_nummer-1
	id_downloaded=$(echo ${ID[$num]})
	CUTLIST=$(grep "<name>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | head -n$cutlist_nummer | tail -n1 | tr -d "\r") #Name der Cutlist
fi

if [ "$toprated" == "no" ] && [ "$continue" == "0" ]; then
	let array_groesse=$array
	let array_groesse--
	CUTLIST_ZAHL=""
	while [ "$CUTLIST_ZAHL" == "" ]; do #Wenn noch keine Cutlist gewählt wurde
		echo -n "Bitte die Nummer der zu verwendenden Cutlist eingeben: "
		read CUTLIST_ZAHL #Benutzereingabe lesen
		if [ -z "$CUTLIST_ZAHL" ]; then
			echo -e "${gelb}Ungültige Auswahl.${normal}"
			CUTLIST_ZAHL=""
		elif [ "$CUTLIST_ZAHL" -gt "$array_groesse" ]; then
			echo -e "${gelb}Ungültige Auswahl.${normal}"
			CUTLIST_ZAHL=""
		fi
	done
	let array_groesse=$CUTLIST_ZAHL
	let CUTLIST_ZAHL++
	id=$(grep "<id>" "$tmp/search.xml" | tail -n$CUTLIST_ZAHL | head -n1 | cut -d">" -f2 | cut -d"<" -f1)
	let num=$CUTLIST_ZAHL-1
	id_downloaded=$(echo ${id[$num]})
	CUTLIST=$(grep "<name>" "$tmp/search.xml" | tail -n$CUTLIST_ZAHL | head -n1 | cut -d">" -f2 | cut -d"<" -f1)
fi

if [ "$continue" == "0" ]; then
	echo -n "Lade $CUTLIST -->"
	#echo $id
	wget -q -O "$tmp/$CUTLIST" "${server}getfile.php?id=$id"
	test_cutlist #Testen der Cutlist
	if [ -f "$tmp/$CUTLIST" ] && [ "$cutlist_okay" == "yes" ]; then
		echo -e "${gruen}okay${normal}"
		continue=0
	else	
		echo -e "${rot}false${normal}"
		if [ "$HaltByErrors" == "yes" ]; then
			exit 1
		else
			continue=1
		fi
	fi
fi
}


#Hier wird überprüft um welches Cutlist-Format es sich handelt
function format ()
{
echo -n "Überprüfe um welches Format es sich handelt --> "
if cat "$tmp/$CUTLIST" | grep "StartFrame=" >> /dev/null; then
	echo -e "${blau}Frames${normal}"
	format=frames
elif cat "$tmp/$CUTLIST" | grep "Start=" >> /dev/null; then
	echo -e "${blau}Zeit${normal}"
	format=zeit
else
	echo -e "${rot}false${normal}"
	echo -e "${rot}Wahrscheinlich wurde das Limit von cutlist.de überschritten!${normal}"
	if [ "$HaltByErrors" == "yes" ]; then
		exit 1
	else
		continue=1
	fi
fi
 }

#Hier wir die Cutlist überprüft, auf z.B. EPGErrors, MissingEnding, MissingVideo, ...
function cutlist_error ()
{
#Diese Variable beinhaltet alle möglichen Fehler
errors="EPGError MissingBeginning MissingEnding MissingVideo MissingAudio OtherError"
for e in $errors; do
	error_check=$(cat "$tmp/$CUTLIST" | grep -m1 $e | cut -d"=" -f2 | tr -d "\r")
	if [ "$error_check" == "1" ]; then
		echo -e "${rot}Es wurde ein Fehler gefunden: \"$e\"${normal}"
		error_yes=$e
		if [ "$error_yes" == "OtherError" ]; then
			othererror=$(cat "$tmp/$CUTLIST" | grep "OtherErrorDescription")
			othererror=${othererror##*=}
			echo -e "${rot}Grund für \"OtherError\": \"$othererror\"${normal}"
		fi
		if [ "$error_yes" == "EPGError" ]; then
			epgerror=$(cat "$tmp/$CUTLIST" | grep "ActualContent")
			epgerror=${epgerror##*=}
			echo -e "${rot}ActualContent: $epgerror${end}"
		fi
		error_found=1
		cutlistWithError="${cutlistWithError} $id_downloaded"
		#echo $cutlistWithError
	fi
done
}

#Hier wird geprüft, welches Seitenverhältnis der Film hat.
#Danke hierfür an MKay aus dem OTR-Forum
function aspectratio ()
{
echo -n "Ermittles Seitenverhältnis --> "

aspectR=$(
		mplayer -vo null -nosound "$film" 2>&1 |
		while read line; do				# Warten bis mplayer aspect-infos liefert oder anfaengt zu spielen
			if [[ $line == "Movie-Aspect is 1.33:1"* ]] || [[ "$line" == "Film-Aspekt ist 1.33:1"* ]]; then
				echo 1
				break
			fi
			if [[ $line == "Movie-Aspect is 0.56:1"* ]] || [[ "$line" == "Film-Aspekt ist 0.56:1"* ]]; then
				echo 2
				break
			fi
			if [[ $line == "Movie-Aspect is 1.78:1"* ]] || [[ "$line" == "Film-Aspekt ist 1.78:1"* ]]; then
				echo 2
				break
			fi
			if [[ $line == "VO: [null]"* ]] ; then
				echo 0
				break
			fi
		done
	)

#echo $aspectR

if [ "$aspectR" -eq 0 ] ; then
	echo -e "${rot}false${normal}"
	if [ "$smart" == "no" ]; then
		aspect=169
	else
		echo -n "Soll der 16:9-Modus verwendet werden? [y|N]? "
		read ASPECT
		if [ "$ASPECT" == "y" ]; then
			aspect=169
			echo "Benutze 16:9-Modus"
		else
			aspect=43
			echo "Benutze den normalen Modus."
		fi
	fi
fi
if [ $aspectR -eq 1 ] ; then
	echo -e "${blau}4:3"${normal}
	aspect=43
fi
if [ $aspectR -eq 2 ] ; then
	echo -e "${blau}16:9${normal}"
	aspect=169
fi
}

#Hier wird geprüft, welche Bildrate der Film hat.
#Florian Knodt <www.adlerweb.info>
function fps ()
{
echo -n "Ermittles Bildrate --> "

fps=50
if file "$film" 2>&1 | grep "25.00 fps" > /dev/null ; then
fps=25
fi
echo $fps
}

#Hier wird nun die Zeit ins richtige Format für avisplit umgerechnet
function time1 ()
{
time=""
let cut_anzahl=$(cat "$tmp/$CUTLIST" | grep "NoOfCuts" | cut -d"=" -f2 | tr -d "\r")
echo "####Auflistung der Cuts####"
if [ "$format" == "zeit" ]; then	#Wenn das verwendete Format "Zeit" ist
	let head1=1
	echo "Es müssen $cut_anzahl Cuts umgerechnet werden."
	while [ "$cut_anzahl" -gt "0" ]; do
		#Die Sekunde in der der Cut beginnen soll
		let time_seconds_start=$(cat "$tmp/$CUTLIST" | grep "Start=" | cut -d"=" -f2 | head -n$head1 | tail -n1 | cut -d"." -f1 | tr -d "\r")
		echo "Startcut: $time_seconds_start. Sekunde"
		time=${time}$(date -u -d @$time_seconds_start +%T-)	#Die Sekunden umgerechned in das Format hh:mm:ss
		#Wie viele Sekunden der Cut dauert
		let time_seconds_ende=$(cat "$tmp/$CUTLIST" | grep "Duration=" | cut -d"=" -f2 | head -n$head1 | tail -n1 | cut -d"." -f1 | tr -d "\r")
		let time_seconds_ende=$time_seconds_ende+$time_seconds_start	#Die Sekunde in der der Cut endet
		echo "Endcut: $time_seconds_ende. Sekunde"
		time=${time}$(date -u -d @$time_seconds_ende +%T,)	#Die Endsekunde im Format hh:mm:ss
		let head1++
		let cut_anzahl--
		#In der Variable $time sind alle Cuts wie folgt aufgelistet:
		#hh:mm:ss-hh:mm:ss,hh:mm:ss-hh:mm:ss,...
	done
elif [ "$format" == "frames" ]; then	#Wenn das verwendete Format "Frames" ist
	let head1=1
	echo "Es müssen $cut_anzahl Cuts umgerechnet werden."
	while [ $cut_anzahl -gt 0 ]; do
		#Der Frame bei dem der Cut beginnt
        	let startframe=$(cat "$tmp/$CUTLIST" | grep "StartFrame=" | cut -d= -f2 | head -n$head1 | tail -n1 | tr -d "\r")
          	echo "Startframe= $startframe"
          	time="${time}$startframe-"
		#Wie viele Frames dauert der Cut
          	let stopframe=$(cat "$tmp/$CUTLIST" | grep "DurationFrames=" | cut -d= -f2 | head -n$head1 | tail -n1 | tr -d "\r")
          	let stopframe=$stopframe+$startframe	#Der Frame bei dem der Cut endet
          	echo "Endframe= $stopframe"
          	time="${time}$stopframe,"	#Auflistung alles Cuts
          	let head1++
          	let cut_anzahl--
		#In der Variable $time sind alle Cuts wie folgt aufgelistet:
		#StartFrame-EndFrame,StartFrame-EndFrame,...
    	done
fi
echo "####ENDE####"
sleep 1
}

#Hier wird nun die Zeit ins richtige Format für avisplit umgerechnet, falls die date-Variante nicht funktioniert
function time2 ()
{
time=""
let cut_anzahl=$(cat "$tmp/$CUTLIST" | grep "NoOfCuts" | cut -d= -f2 | tr -d "\r")
echo "#####Auflistung der Cuts#####"
if [ $format == "zeit" ]; then
	let head1=1
   	echo "Es müssen $cut_anzahl Cuts umgerechnet werden"
   	while [ $cut_anzahl -gt 0 ]; do
		#Die Sekunde in der der Cut startet
      		let time_seconds_start=$(cat "$tmp/$CUTLIST" | grep "Start=" | cut -d= -f2 | head -n$head1 | tail -n1 | cut -d"." -f1 | tr -d "\r")
      		let ss=$time_seconds_start	#Setze die Skunden auf $time_seconds_start
      		let mm=0	#Setze die Minuten auf 0
      		let hh=0	#Setze die Stunden auf 0
      		while [ $ss -ge "60" ]; do	#Wenn die Sekunden >= 60 sind
         		let mm++	#Zähle Minuten um 1 hoch
         		let ss=$ss-60	#Zähle Sekunden um 60 runter
         		while [ $mm -ge "60" ]; do	#Wenn die Minuten >= 60 sind
            			let hh++	#Zähle Stunden um 1 hoch
            			let mm=$mm-60	#Zähle Minuten um 60 runter
         		done
      		done
      		time2_start=$hh:$mm:$ss	#Bringe die Zeit ins richtige Format
      		echo "Startcut= $time2_start"
      		time="${time}${time2_start}-"	#Auflistung aller Zeiten
		#Sekunden wie lange der Cut dauert
      		let time_seconds_ende=$(cat "$tmp/$CUTLIST" | grep "Duration=" | cut -d= -f2 | head -n$head1 | tail -n1 | cut -d"." -f1 | tr -d "\r")
      		let time_seconds_ende=$time_seconds_ende+$time_seconds_start	#Die Sekunde in der der Cut endet
      		let ss=$time_seconds_ende	#Setze die Sekunden auf $time_seconds_ende
      		let mm=0	#Setze die Minuten auf 0
      		let hh=0	#Setze die Stunden auf 0
      		while [ $ss -ge "60" ]; do	#Wenn die Sekunden >= 60 sind
        		let mm++	#Zähle Minuten um 1 hoch
			let ss=$ss-60	#Zähle Sekunden um 60 runter
         		while [ $mm -ge "60" ]; do	#Wenn die Minuten >= 60 sind
            			let hh++	#Zähle Stunden um 1 hoch
            			let mm=$mm-60	#Z#hle Minuten um 60 runter
         		done
      		done
      		time2_ende=$hh:$mm:$ss	#Bringe die Zeit ins richtige Format
      		echo "Endcut= $time2_ende"
      		time="${time}${time2_ende},"	#Auflistung alles Zeiten
   	done
elif [ $format == "frames" ]; then
	let head1=1
    	echo "Es müssen $cut_anzahl Cuts umgerechnet werden"
    	while [ $cut_anzahl -gt 0 ]; do
		#Der Frame bei dem der Cut beginnt
		let startframe=$(cat "$tmp/$CUTLIST" | grep "StartFrame=" | cut -d= -f2 | head -n$head1 | tail -n1 | tr -d "\r")
          	echo "Startframe= $startframe"
          	time="${time}$startframe-"	#Auflistung der Cuts
		#Die Frames wie lange der Cut dauert
		let stopframe=$(cat "$tmp/$CUTLIST" | grep "DurationFrames=" | cut -d= -f2 | head -n$head1 | tail -n1 | tr -d "\r")
          	let stopframe=$stopframe+$startframe	#Der Frame bei dem der Cut endet
          	echo "Endframe= $stopframe"
          	time="${time}$stopframe,"	#Auflistung der Cuts
          	let head1++
          	let cut_anzahl--
    	done
fi
echo "#####ENDE#####"
sleep 1
}

#Hier wird nun, falls aviplit/avimerge gewählt wurde, avisplit und avimerge gestartet
function split ()
{
echo "Übergebe die Cuts an avisplit/avimerge"

if [ $decoded == "yes" ]; then
	nice -n 15 avisplit -i "$output/$film" -o "$outputfile" -t $time -c 	#Hier wird avisplit gestartet, avimerge wird on-the-fly über den Parameter -c gestartet
else
	nice -n 15 avisplit -i "$film" -o "$outputfile" -t $time -c 	#Hier wird avisplit gestartet, avimerge wird on-the-fly über den Parameter -c gestartet
fi
if [ -f "$outputfile" ]; then
	echo -e "${gruen}$outputfile wurde erstellt${normal}"
	if [ "$delete" == "yes" ]; then
		echo "Lösche Quellvideo."
		if [ $decoded == "yes" ]; then		
			nice -n 15 rm -rf "$output/$film"
		else
			nice -n 15 rm -rf "$film"
		fi
	fi
else
	echo -e "${rot}Avisplit oder avimerge muss einen Fehler verursacht haben.${normal}"
	if [ "$HaltByErrors" == "yes" ]; then
		exit 1
	else
		continue=1
	fi
fi
}

#Hier wird nun, fals avidemux gewählt wurde, avidemux gestartet
function demux ()
{
#In dieser Funktion wird der Projektanfang definiert
function start1 ()
{
cat << EOF
//AD <- Needed to identify//
var app = new Avidemux();

//** Video **
// 01 videos source
EOF
}

#Schreibe die Ausgabe von start in eine Datei
start1 >> "$tmp/avidemux.js"

if [ "$ad_version" == "old" ]; then
	if [ "$decoded" == "yes" ]; then
		echo "app.load(\"$output/$film\")" >> "/$tmp/avidemux.js"
	else
		echo "app.load(\"$film\")" >> "/$tmp/avidemux.js"
	fi
elif [ "$ad_version" == "new" ]; then
	if [ "$decoded" == "yes" ]; then
		echo "app.load(\"$output_new/$film\")" >> "/$tmp/avidemux.js"
	else
		echo "app.load(\"$film_new_ad\")" >> "/$tmp/avidemux.js"
	fi
fi

function start2 ()
{
cat << EOF
//$cut_anzahl segments
app.clearSegments();
EOF
}
#Schreibe die Ausgabe von start in eine Datei
start2 >> "$tmp/avidemux.js"

let cut_anzahl=$(cat "$tmp/$CUTLIST" | grep "NoOfCuts" | cut -d= -f2 | tr -d "\r")
echo "#####Auflistung der Cuts#####"
if [ "$format" = "zeit" ]; then
	let head2=1
	echo "Es müssen $cut_anzahl Cuts umgerechnet werden"
	while [ "$cut_anzahl" -gt 0 ]; do
		let time_seconds_start=$(cat "$tmp/$CUTLIST" | grep "Start=" | cut -d= -f2 | head -n$head2 | tail -n1 | cut -d"." -f1 | tr -d "\r")
          	let time_frame_start=$time_seconds_start*$fps
          	echo "Startframe= $time_frame_start"
          	let time_seconds_dauer=$(cat "$tmp/$CUTLIST" | grep "Duration=" | cut -d= -f2 | head -n$head2 | tail -n1 | cut -d"." -f1 | tr -d "\r")
          	let time_frame_dauer=$time_seconds_dauer*$fps
          	echo "Dauer= $time_frame_dauer"
          	echo "app.addSegment(0,$time_frame_start,$time_frame_dauer);" >> "$tmp/avidemux.js"
          	let head2++
          	let cut_anzahl--
    	done
elif [ "$format" = "frames" ]; then
	let head2=1
    	echo "Es müssen $cut_anzahl Cuts umgerechnet werden"
    	while [ $cut_anzahl -gt 0 ]; do
		let startframe=$(cat "$tmp/$CUTLIST" | grep "StartFrame=" | cut -d= -f2 | head -n$head2 | tail -n1 | tr -d "\r")
          	echo "Startframe= $startframe"
          	let dauerframe=$(cat "$tmp/$CUTLIST" | grep "DurationFrames=" | cut -d= -f2 | head -n$head2 | tail -n1 | tr -d "\r")
          	echo "Dauer= $dauerframe"
          	echo "app.addSegment(0,$startframe,$dauerframe);" >> "$tmp/avidemux.js"
          	let head2++
          	let cut_anzahl--
    	done
fi

echo "#####ENDE#####"
sleep 1

if [ "$ad_version" == "old" ]; then
	if echo "$film_ohne_anfang" | grep -q ".HQ."; then
		outputfile="$output/$film_ohne_ende.HQ-cut.avi"
	elif echo "$film_ohne_anfang" | grep -q ".mp4"; then
   		outputfile="$output/$film_ohne_ende-cut.mp4"
	else
   		outputfile="$output/$film_ohne_ende-cut.avi"
	fi
else
	if echo "$film_ohne_anfang" | grep -q ".HQ."; then
		outputfile="$output/$film_ohne_ende.HQ-cut.avi"
	elif echo "$film_ohne_anfang" | grep -q ".mp4"; then
   		outputfile="$output/$film_ohne_ende-cut.mp4"
	else
 	  	outputfile="$output/$film_ohne_ende-cut.avi"
	fi
fi

function ende ()
{ 
fpsjs=$(($fps*1000))
cat << EOF

//** Postproc **
app.video.setPostProc(3,3,0);
app.video.setFps1000($fpsjs);

//** Filters **

//** Video Codec conf **
app.video.codec("$vidcodec","CQ=4","0 ");

//** Audio **
app.audio.reset();
app.audio.codec("copy",128,0,"");
app.audio.normalizeMode=0;
app.audio.normalizeValue=0;
app.audio.delay=0;
app.audio.mixer("NONE");
app.audio.scanVBR();
app.setContainer("AVI");
setSuccess(app.save("$outputfile"));
//app.Exit();

//End of script
EOF
}

function ende_new ()
{ 
fpsjs=$(($fps*1000))
cat << EOF

//** Postproc **
app.video.setPostProc(3,3,0);
app.video.fps1000=$fpsjs;

//** Filters **

//** Video Codec conf **
app.video.codec("$vidcodec","CQ=4","0 ");

//** Audio **
app.audio.reset();
app.audio.codec("copy",128,0,"");
app.audio.normalizeMode=0;
app.audio.normalizeValue=0;
app.audio.delay=0;
app.audio.mixer="NONE";
app.audio.scanVBR=""
app.setContainer="AVI";
setSuccess(app.save("$outputfile"));
//app.Exit();

//End of script
EOF
}

if [ "$ad_version" == "old" ]; then
	ende >> "$tmp/avidemux.js"
else
	ende_new >> "$tmp/avidemux.js"
fi

echo "Übergebe die Cuts nun an avidemux"

#if [ "$aspect" == "43" ]; then
if [ "$smart" == "yes" ]; then
	if [ "$verbose" == "yes" ]; then
		nice -n 15 $CutProg --nogui --force-smart --run "$tmp/avidemux.js" --quit
	else
		nice -n 15 $CutProg --nogui --force-smart --run "$tmp/avidemux.js" --quit >> /dev/null
	fi
#elif [ "$aspect" == "169" ]; then
elif [ "$smart" == "no" ]; then
	if [ "$verbose" == "yes" ]; then
		nice -n 15 $CutProg --nogui --run "$tmp/avidemux.js" --quit
	else
		nice -n 15 $CutProg --nogui --run "$tmp/avidemux.js" --quit >> /dev/null
	fi
fi

if [ -f "$outputfile" ]; then
	echo -n -e  ${gruen}$outputfile${normal}
     	echo -e "${gruen} wurde erstellt${normal}"
	if [ "$delete" == "yes" ]; then
		echo "Lösche Quellvideo."	
		if [ $decoded == "yes" ]; then		
			nice -n 15 rm -rf "$output/$film"
		else
			nice -n 15 rm -rf "$film"
		fi
	fi
else
     	echo -e "${rot}Avidemux muss einen Fehler verursacht haben${normal}"
     	if [ $HaltByErrors == "yes" ]; then
        	  exit 1
     	else
        	  continue=1
     	fi
fi
}

#Hier wird nun, wenn gewünscht, eine Bewertung für die Cutlist abgegeben
function bewertung ()
{
echo ""
echo "Sie können nun eine Bewertung für die Cutlist abgeben."
echo "Folgende Noten stehen zur verfügung:"
echo "[0] Test (schlechteste Wertung)"
echo "[1] Anfang und Ende geschnitten"
echo "[2] +/- 5 Sekunden"
echo "[3] +/- 1 Sekunde"
echo "[4] Framegenau"
echo "[5] Framegenau und keine doppelten Szenen"
echo ""
echo "Sollten Sie für diese Cutlist keine Bewertung abgeben wollen,"
echo "drücken Sie einfach ENTER."
echo -n "Note: "
note=""
read note
while [ ! "$note" == "" ] && [ "$note" -gt "5" ]; do
	note=""
 	echo -e "${gelb}Ungültige Eingabe, bitte nochmal:${normal}"
  	read note
done
if [ "$note" == "" ]; then
	echo "Für diese Cutlist wird keine Bewertung abgegeben."
else
	echo -n "Übermittle Bewertung für $CUTLIST -->"
	if [ "$personal" == "yes" ]; then
		wget -q -O "$tmp/rate.php" "${personalurl}rate.php?rate=$id&rating=$note&userid=$cutlistuser&version=0.9.8.7"
	else
		wget -q -O "$tmp/rate.php" "http://cutlist.at/rate.php?rate=$id&rating=$note&userid=$user&version=0.9.8.7"
	fi
	sleep 1
	if [ -f "$tmp/rate.php" ]; then
		if cat "$tmp/rate.php" | grep -q "Cutlist nicht von hier. Bewertung abgelehnt."; then
    			echo -e " ${rot}False${normal}"	
      			echo -e " ${rot}Die Cutlist ist nicht von http://cutlist.at und kann nicht bewertet werden.${normal}"
	   	elif cat "$tmp/rate.php" | grep -q "Du hast schon eine Bewertung abgegeben oder Cutlist selbst hochgeladen."; then
	   	   	echo -e " ${rot}False${normal}"
	      		echo -e "${rot}Du hast für die Cutlist schonmal eine Bewertung abgegeben oder sie selbst hochgeladen.${normal}"
		elif cat "$tmp/rate.php" | grep -q "Sie haben diese Liste bereits bewertet"; then
	      		echo -e " ${rot}False${normal}"
	      		echo -e "${rot}Du hast für die Cutlist schonmal eine Bewertung abgegeben oder sie selbst hochgeladen.${normal}"
	   	elif cat "$tmp/rate.php" | grep -q "Cutlist wurde bewertet"; then
	      		echo -e "${gruen}Okay${normal}"
	      		echo -e "${gruen}Cutlist wurde bewertet${normal}"
	   	fi
   	else
	  	echo -e "${rot}False${normal}"
	  	echo -e "${rot}Bewertung fehlgeschlagen.${normal}"
   	fi
fi
}

#Hier wird ein Otrkey-File dekodiert, falls es gewünscht ist
function decode ()
{
if echo $i | grep -q .otrkey; then
	if [ ! "$email_checked" == "yes" ]; then
		if [ "$email" == "" ]; then
			echo -e "${rot}Kann nicht dekodieren da keine EMail-Adresse angegeben wurde!${normal}"
			exit 1
		elif [ "$password" == "" ]; then
			echo -e "${rot}Kann nicht dekodieren da kein Passwort angegeben wurde!${normal}"#
			exit 1
		else
			email_checked=yes
		fi
	fi
	echo "Decodiere Datei --> "
	nice -n 15 $decoder -e "$email" -p "$password" -q -f -i "$i" -o "$output"
	otrkey=$i
	decoded=yes
else
	decoded=no
fi
if [ "$delete" == "yes" ]; then
	echo "Lösche OtrKey"
	rm -rf "$otrkey"
fi
}

#Hier werden nun die temporären Dateien gelöscht
function del_tmp ()
{
if [ "$tmp" == "" ] || [ "$tmp" == "/" ] || [ "$tmp" == "/home" ]; then
	echo -e "${rot}Achtung, bitte überprüfen Sie die Einstellung von \$tmp${normal}"
	exit 1
fi
echo "Lösche temporäre Dateien"
#echo $tmp
rm -rf "$tmp"/*
}


if [ "$warn" == "yes" ]; then
	warnung
fi
datei
#del_tmp

#if [ "$server" == "0" ]; then
#   	echo "Verwende  http://cutlist.de als Server."
#elif [ "$server" == "1" ]; then
#   	echo "Verwende http://cutlist.at als Server"
#elif [ "$server" == "2" ]; then
#   	echo "Verwende http://cutlist.mbod.net als Server"
#fi
software
	for i in "${input[@]}"; do
       		test
		del_tmp
		decode
       		name
       	if [ "$UseLocalCutlist" == "yes" ]; then
           	local
       	fi
        
       	while true; do
		if [ "$UseLocalCutlist" == "no" ] || [ "$vorhanden" == "no" ]; then
           		load
       		fi
       		if [ "$continue" == "0" ]; then
         	  	format
		fi
		#if [ "$continue" == "0" ]; then
         	#  	aspectratio
		#fi
        if [ "$continue" == "0" ]; then
         	  	fps
		fi
		if [ "$continue" == "0" ]; then
			cutlist_error
		fi
		if [ "$error_found" == "1" ] && [ "$toprated" == "no" ]; then
			echo -e "${gelb}In der Cutlist wurde ein Fehler gefunden, soll sie verwendet werden? [y|n]${normal}"
			read error_antwort
			if [ "$error_antwort" == "y" ]; then
				echo -e "${gelb}Verwende die Cutlist trotz Fehler!${normal}"
				break
			else
				echo "Bitte neue Cutlist wählen!"
			fi
		else
			break
		fi
		if [ "$error_found" == "1" ] && [ "$toprated" == "yes" ]; then
			break
		fi
       	done
       	if [ "$CutProg" = "avisplit" ] && [ $continue == "0" ]; then
           	if [ "$date_okay" = "yes" ]; then
              		time1
           	elif [ "$date_okay" = "no" ]; then
              		time2
           	fi
           	if [ "$overwrite" == "no" ]; then
              		if [ ! -f "$output/$film_ohne_ende-cut.avi" ]; then
                 		split
              		else
                 		echo -e "${gelb}Die Ausgabedatei existiert bereits!${normal}"
                 		if [ $HaltByErrors == "yes" ]; then
                    			exit 1
                 		else
                    			continue=1
                 		fi
              		fi
           	fi
           	if [ "$overwrite" == "yes" ]; then
              		split
           	fi
       	fi
       	if [ "$CutProg" = "avidemux" ] || [ "$CutProg" = "avidemux2" ] || [ "$CutProg" = "avidemux2_cli" ] || [ "$CutProg" = "avidemux2_qt4" ] || [ "$CutProg" = "avidemux2_gtk" ] && [ $continue == "0" ]; then
           	if [ "$overwrite" == "no" ]; then
              		if [ ! -f "$output/$film_ohne_ende-cut.avi" ]; then
                 		demux
              		else
                 		echo -e "${gelb}Die Ausgabedatei existiert bereits!${normal}"
                 		if [ $HaltByErrors == "yes" ]; then
                    			exit 1
                 		else
                    			continue=1
                 		fi
              		fi
           	fi
           	if [ "$overwrite" == "yes" ]; then
              		demux
           	fi
       	fi
       	if [ "$UseLocalCutlist" == "no" ] && [ "$bewertung" == "yes" ] && [ ! "$continue" == "1" ]; then
	   	if [ "$play" == "no" ]; then
	      		bewertung
	   	elif [ "$play" == "yes" ]; then
	      		echo "Starte nun den gewählten Videoplayer"
	      		sleep 1
              		$player "$outputfile"
              		bewertung
	   	fi
       	fi
	if [ "$decoded" == "yes" ]; then
		rm -rf "$output/$film"
	fi
   	del_tmp
   	continue=0
done
