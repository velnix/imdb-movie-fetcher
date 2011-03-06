#!/bin/bash
#IMDB Movie fetcher
#an IMDB movie data fetcher developed by Unnikrishnan.A
#unnikrishnan.a@gmail.com
#http://imdbmoviefetche.sourceforge.net/
#version 3.1
shopt -s -o nounset
#Global variable declarations
declare -rx MYSITE="http://imdbmoviefetche.sourceforge.net/"
declare -rx MYMAIL="unnikrishnan.a@gmail.com"
declare -rx SCRIPT=${0##*/}
declare -rx VERSION="3.1"
declare URL
declare TITLE
declare YEAR
declare RAT
declare PLOT
declare MOVIE
declare DIR
declare GEN
declare CAST
declare -rx TMPFILE=/tmp/imdbmoviefetcher.$$
declare -rx PLOTFILE=/tmp/plot.$$.html
declare -rx LYNX="/usr/bin/lynx"
declare -rx CAT="/bin/cat"
declare -rx SED="/bin/sed"
declare -rx EGREP="/bin/egrep"
declare -rx GREP="/bin/grep"
declare -rx UNIQ="/usr/bin/uniq"
declare -rx HEAD="/usr/bin/head"
declare SWITCH
declare -r OPTSTRING=":hvt:"
#check the input arguments/ parametrs
if [ $# -eq 0 ];then
printf "%s -h for more information\n" "$SCRIPT"
exit 192
fi
while getopts "$OPTSTRING" SWITCH;do
case "$SWITCH" in
h) cat << EOF
   $SCRIPT [option] [arg]

   Options : 
   -v : gives the version of the script
   -h : shows the help page
   -t [arg] : Pass the movie title as argument. It is recommended to quote the name as shown in the example below 

   Example : 
   $SCRIPT -t "startship troopers"
 
   Send your feedback to $MYMAIL
   Visit: $MYSITE

EOF
   exit 0
   ;;
t) MOVIE="$OPTARG"
   ;;
v) printf "IMDB movie fetcher version %s.\nSend your feedbacks to %s\nVisit: %s\n" "$VERSION" "$MYMAIL" "$MYSITE"
   exit 0
   ;;
\?) printf "%s\n" "Invalid option. use $SCRIPT -h for more information"
    exit 192
    ;;
*) printf "%s\n" "Invalid argument. use $SCRIPT -h for more information"
   exit 192
    ;;
esac
done
[[ -z $MOVIE ]] && { printf "%s -h for more information\n" "$SCRIPT";exit 192;}
#functions
printnofound() {
printf "There is no $1 command. Please install it\n"
}
#Sanity checks
if [ -z "$BASH" ]
then
printf "This script is written for bash. Please run this under bash\n" >&2
exit 192
fi
if [ ! -x "$LYNX" ]
then
printnofound $LYNX >&2
exit 192
fi
if [ ! -x "$CAT" ]
then
printnofound $CAT >&2
exit 192
fi
if [ ! -x "$EGREP" ]
then
printnofound $EGREP >&2
exit 192
fi
if [ ! -x "$GREP" ]
then
printnofound $GREP >&2
exit 192
fi
if [ ! -x "$UNIQ" ]
then
printnofound $UNIQ >&2
exit 192
fi
if [ ! -x "$HEAD" ]
then
printnofound $HEAD >&2
exit 192
fi
if [ ! -x "$SED" ]
then
printnofound $SED >&2
exit 192
fi
#sanity check finished
#replace special characters in the movie name argument
MOVIE=`echo $MOVIE | sed -r 's/  */\+/g;s/\&/%26/g;s/\++$//g'`
#search the title in google
$LYNX -connect_timeout=10 --source "http://www.google.com/search?hl=en&q=$MOVIE+imdb" > $TMPFILE 2> /dev/null
#Check if lynx is successful
if [ $? -ne 0 ]
then 
printf "Connection to site failed...Please check your internet connection\n"
exit 192
fi
#Get IMDB URL for the film
URL=`$EGREP -o "http://www.imdb.com/title/tt[0-9]*/" $TMPFILE | $HEAD -1`
#get the details from movie page
$LYNX --source ${URL} > $TMPFILE;
#extract data
YEAR=`$CAT $TMPFILE | $SED -n '/<h1.*>/,/<\/h1>/p' | $SED '1d;$d;/^$/d;s/<[^>]*>//g;s/(//g;s/)//g' | $EGREP -o "[0-9][0-9][0-9][0-9]"`
TITLE=`$CAT $TMPFILE | $SED -n '/<h1.*>/,/<\/h1>/p' | $SED '1d;$d;/^$/d;s/<[^>]*>//g;s/(//g;s/)//g' | $HEAD -1 | $SED "s/\&#x27\;/\'/g"`
$SED -n '/<h1.*>/,/<\/p>/p' $TMPFILE | $SED -n '/<p>/,/<\/p>/{ s/<[^>]*>//g;p;}' | $SED 's/See full summary.*//g' > $PLOTFILE 
PLOT=`lynx --dump $PLOTFILE | sed 's/^  *//g'`
RAT=`$SED -n '/<span class="rating-rating">/{ s/<[^>]*>//g;p;}' $TMPFILE`;
DIR=`$SED -n '/ *Director[s]*:.*/,/ *Writer[s]*:.*/{ /<a *href="\/name\/nm[0-9][0-9]*\/"[^>]*>[^<]*<\/a>.*/p;}' $TMPFILE | $SED  's/<\/a>/<\/a>\n/g' | $SED -n 's/.*<a *href="\/name\/nm[0-9][0-9]*\/"[^>]*>\([^<]*\)<\/a>.*/\1/p;' | tr '\n' ';' | $SED 's/\;*$//g'`
GEN=`$SED -n '/genre/p' $TMPFILE | $EGREP -o '<a  *.*href="/genre/[a-zA-Z][a-z]*"[^>]*>[^<]*</a>' | $SED 's/<[^>]*>//g;s/&nbsp\;//g;s/ *Genres *[0-9][0-9]* *min-//g;s/|/,/g' | $SED 's/[gG]enres//g;s/^  *//g' | $UNIQ | $HEAD -1`
CAST=`$SED -n '/.*Star[s]*:.*/,/<\/div>/{ s/<[^>]*>//g;s/Stars://g;p }' $TMPFILE | $SED -n '/^ *$/d;p'`
#print everything
printf "\nTitle    : $TITLE\n"
printf "Year     : $YEAR\n"
printf "Rating   : $RAT\n"
printf "Director : $DIR\n"
printf "Genres   : $GEN\n"
printf "Cast     : $CAST\n"
printf "Plot     :\n\n%s\n\n" "$PLOT"
printf "IMDB movie URL : ${URL}\n\n"
rm $TMPFILE > /dev/null
rm $PLOTFILE > /dev/null
exit 0
