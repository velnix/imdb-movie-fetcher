#!/bin/bash
#Movie fetcher
#Movie data fetcher developed by Unni <unnikrishnan.a@gmail.com>
#Code to fetch poster, machine readable output and bug fixes by
#Mikhail Fedotov <anyremote@mail.ru>
#http://prj.mutexes.org/projects/imdbmoviefetcher
#version 4.2
shopt -s -o nounset
#Global variable declarations
declare -rx MYSITE="http://prj.mutexes.org/projects/imdbmoviefetcher"
declare -rx SOURCE_REPO="https://github.com/webofunni/imdb-movie-fetcher"
declare -rx SCRIPT=${0##*/}
declare -rx VERSION="4.2"
declare URL
declare TITLE
declare YEAR
declare RATING
declare PLOT
declare MOVIE
declare POSTER=0
declare PARSEABLE=0
declare DIRECTOR
declare GENRE
declare CAST
declare POSTERURL
declare -rx TMPFILE=/tmp/imdbmoviefetcher.$$
declare -rx PLOTFILE=/tmp/plot.$$.html
declare -rx LYNX="/usr/bin/lynx"
declare -rx CAT="/bin/cat"
declare -rx SED="/bin/sed"
declare -rx EGREP="/bin/egrep"
declare -rx GREP="/bin/grep"
declare -rx UNIQ="/usr/bin/uniq"
declare -rx HEAD="/usr/bin/head"
declare -rx SORT=`which sort`
declare SWITCH
declare -r OPTSTRING=":hvpmt:"
declare -i INEEDCOLOR
declare TITLECOLOR="White"
declare DATACOLOR="White"
declare LINKCOLOR="White"
declare CONFFILE="/etc/imdb-mf.conf"
declare COLOR_START=""
declare COLOR_END=""
INEEDCOLOR=0
#Get color for colorised output
if [ -f $HOME/.imdb-mf.conf ]
then
CONFFILE=$HOME/.imdb-mf.conf 
fi
if [ -f $CONFFILE ]
then 
declare COLOR_START='\033['
declare COLOR_END='\033[0m'
. $CONFFILE
fi
getcolor()
{
COMPONENT=$1
VAR=$2
case $COMPONENT in
Black) eval ${VAR}_CODE=30
      eval ${VAR}_MODE=0
      ;;
Red)eval ${VAR}_CODE=31
    eval ${VAR}_MODE=0
    ;;
Green)eval ${VAR}_CODE=32
    eval ${VAR}_MODE=0
   ;;
Yellow)eval ${VAR}_CODE=33
    eval ${VAR}_MODE=0
;;
Blue)eval ${VAR}_CODE=34
    eval ${VAR}_MODE=0
;;
Purple)eval ${VAR}_CODE=35
    eval ${VAR}_MODE=0
;;
Cyan)eval ${VAR}_CODE=36
    eval ${VAR}_MODE=0
;;
Gray)eval ${VAR}_CODE=37
    eval ${VAR}_MODE=0
;;
DGray)eval ${VAR}_CODE=30
    eval ${VAR}_MODE=1
;;
DRed)eval ${VAR}_CODE=31
    eval ${VAR}_MODE=1
;;
DGreen)eval ${VAR}_CODE=32
    eval ${VAR}_MODE=1
;;
DYellow)eval ${VAR}_CODE=33
    eval ${VAR}_MODE=1
;;
DBlue)eval ${VAR}_CODE=34
    eval ${VAR}_MODE=1
;;
DPurple)eval ${VAR}_CODE=35
    eval ${VAR}_MODE=1
;;
DCyan)eval ${VAR}_CODE=36
    eval ${VAR}_MODE=1
;;
White)eval ${VAR}_CODE=37
    eval ${VAR}_MODE=1
;;
*)eval ${VAR}_CODE=37
eval ${VAR}_MODE=0
;;
esac
}
if [ $INEEDCOLOR -eq 1 ]
then
getcolor $TITLECOLOR TITLECOLOR
getcolor $DATACOLOR DATACOLOR
getcolor $LINKCOLOR LINKCOLOR
else
TITLECOLOR=""
DATACOLOR=""
LINKCOLOR=""
fi
#End of colorse function
#check the input arguments/ parametrs
if [ $# -eq 0 ];then
printf "%s -h for more information\n" "$SCRIPT"
exit 192
fi
while getopts "$OPTSTRING" SWITCH;do
case "$SWITCH" in
h) cat << EOF
Usage: $SCRIPT [option] [arg]
Get movie details without leaving bash

Options : 
   -v : gives the version of the script
   -h : shows the help page
   -t [arg] : Pass the movie title as argument. It is recommended to quote the name as shown in the example below 
   -p : Download movie poster. Use it with -t option.
   -m : Output in machine-readable format, easy for subsequent parsing. Use it with -t option.

Example : 
   $SCRIPT -t "cars"
 
Bugs, feature requests etc : $MYSITE
Source code : $SOURCE_REPO   
EOF
   exit 0
   ;;
t) MOVIE="$OPTARG"
   ;;
p) POSTER="1"
   ;;
m) PARSEABLE="1"
   INEEDCOLOR="0"
   ;;
v) printf "IMDB movie fetcher version %s.\n\nBugs, Feature requests etc : %s\nSource code : %s\n" "$VERSION" "$MYSITE" "$SOURCE_REPO"
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
[[ ${MOVIE:-unset} == 'unset' || -z $MOVIE ]] && { printf "Invalid input. Execute %s -h for more information\n" "$SCRIPT";exit 192;}
#functions
printnofound() {
printf "There is no $1 command. Please install it\n"
}
sancheck() {
BINARY=$1
if [ ! -x "$BINARY" ]
then
printnofound $BINARY >&2
exit 192
fi
}
#Sanity checks
if [ -z "$BASH" ]
then
printf "This script is written for bash. Please run this under bash\n" >&2
exit 192
fi
# do sancheck only for utilities which absent in coreutils package
sancheck $LYNX
sancheck $EGREP
sancheck $GREP
sancheck $SED
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
#Get similar titles
SIMILARTITLES=`egrep -o "<a[^>]+>[^<]*(<b>[^<|^(imdb)]+</b>)*[^<]*<b>[^<]*</b>[^\(|^<]*\([0-9]+\)[^-]+-[^<]*<b>IMDb</b>" $TMPFILE | grep "www.imdb.com" | sort | uniq | sed 's/- <b>IMDb<\/b>//g' | sed 's/<[^>]*>//g'`
#get the details from movie page
$LYNX --source ${URL} > $TMPFILE;
if [ $? -ne 0 ]
then 
printf "Connection to site failed...Please check your internet connection\n"
exit 192
fi
#extract data
YEAR=`$CAT $TMPFILE | $SED -n '/<h1.*>/,/<\/h1>/p' | $SED -n '/<span.*>/,/<\/span>/p' | $SED '/^$/d;s/<[^>]*>//g;s/(//g;s/)//g' | $SED 's/&ndash;/ - /g'| $EGREP -o "[0-9][0-9][0-9][0-9]( - [0-9][0-9][0-9][0-9])*"`
TITLE=`$CAT $TMPFILE | $SED -n '/<h1.*>/,/<\/h1>/p' | $SED '1d;$d;/^$/d;s/<[^>]*>//g;s/(//g;s/)//g' | $HEAD -1 | $SED "s/\&#x27\;/\'/g"`
POSTERURL=`grep "Poster" $TMPFILE -B4|grep -o http.*\.jpg`
if [ $POSTER -eq 1 ] 
then
POSTERFILE=`echo $TITLE | $SED "s/ /_/g"`
$LYNX -connect_timeout=10 --source $POSTERURL > ${POSTERFILE}.jpg 2> /dev/null
fi
#Get the plot in a html file
$SED -n '/<h1.*>/,/<\/p>/p' $TMPFILE | $SED -n '/<p>/,/<\/p>/{ s/<[^>]*>//g;p;}' | $SED 's/See full summary.*//g' > $PLOTFILE 
PLOT=`lynx --dump $PLOTFILE | sed 's/^  *//g'`
RATING=`$SED -n '/<span itemprop="ratingValue">/{ s/<[^>]*>//g;p;}' $TMPFILE  | $EGREP -o "[0-9]+\.[0-9]+/[0-9]+" | tail -1`;
DIRECTOR=`$SED -n '/ *Director[s]*:.*/,/ *Writer[s]*:.*/{p;}' $TMPFILE | $SED -n '/ *Director[s]*:.*/,/ *Star[s]*:.*/{p;}' | $SED '1d;$d' | tr '\n' ' ' | $SED 's/<[^>]*>//g;s/^ *//g;s/ *$//g;s/&nbsp;&raquo;//g'`
GENRE=`$SED -n '/genre/p' $TMPFILE | $EGREP -o '<a  *.*href="/genre/[a-zA-Z][a-z]*"[^>]*>[^<]*</a>' | $SED 's/<[^>]*>//g;s/&nbsp\;//g;s/ *Genres *[0-9][0-9]* *min-//g;s/|/,/g' | $SED 's/[gG]enres//g;s/^  *//g' | $UNIQ | $HEAD -1`
CAST=`$SED -n '/.*Star[s]*:.*/,/<\/div>/{ s/<[^>]*>//g;s/Stars://g;p }' $TMPFILE | grep -v "See full cast and crew" | $SED -n '/^ *$/d;p' | tr '\n' ' ' | $SED 's/<[^>]*>//g;s/|//g'`
if [ $INEEDCOLOR -eq 1 ] 
then
TITLE_COLOR_TAG="${TITLECOLOR_MODE};${TITLECOLOR_CODE}m"
DATA_COLOR_TAG="${DATACOLOR_MODE};${DATACOLOR_CODE}m"
LINK_COLOR_TAG="${LINKCOLOR_MODE};${LINKCOLOR_CODE}m"
else
TITLE_COLOR_TAG=""
DATA_COLOR_TAG=""
LINK_COLOR_TAG=""
fi
if [ $PARSEABLE -eq 1 ] 
then
PLOT=`echo $PLOT | tr -d '\n'`
fi
#print everything
printf "\n${COLOR_START}${TITLE_COLOR_TAG}Title${COLOR_END}      : ${COLOR_START}${DATA_COLOR_TAG}$TITLE${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Year${COLOR_END}       : ${COLOR_START}${DATA_COLOR_TAG}$YEAR${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Rating${COLOR_END}     : ${COLOR_START}${DATA_COLOR_TAG}$RATING${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Director${COLOR_END}   : ${COLOR_START}${DATA_COLOR_TAG}$DIRECTOR${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Genres${COLOR_END}     : ${COLOR_START}${DATA_COLOR_TAG}$GENRE${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Cast${COLOR_END}       : ${COLOR_START}${DATA_COLOR_TAG}$CAST${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Plot${COLOR_END}       : ${COLOR_START}${DATA_COLOR_TAG}%s${COLOR_END}\n" "$PLOT"
printf "\n${COLOR_START}${TITLE_COLOR_TAG}IMDB movie URL${COLOR_END} : ${COLOR_START}${LINK_COLOR_TAG}${URL}${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Poster URL${COLOR_END} : ${COLOR_START}${LINK_COLOR_TAG}${POSTERURL}${COLOR_END}\n"
if [ $PARSEABLE -eq 0 ] 
then
printf "${COLOR_START}${TITLE_COLOR_TAG}\n==============Other similar Titles=============${COLOR_END}\n\n"
if [ -z "$SIMILARTITLES" ]
then
SIMILARTITLES="Nothing interesting here"
fi
printf "${COLOR_START}${DATA_COLOR_TAG}%s${COLOR_END}\n" "$SIMILARTITLES"
printf "\n${COLOR_START}${TITLE_COLOR_TAG}Use above key words to know more about them${COLOR_END}\n"
else
if [ ! -z "$SIMILARTITLES" ]
then
printf "${COLOR_START}${TITLE_COLOR_TAG}Similarities${COLOR_END} : ${COLOR_START}${LINK_COLOR_TAG}%s${COLOR_END}\n" "$SIMILARTITLES"    
fi
fi
#Done. Now do cleanup
rm $TMPFILE > /dev/null
rm $PLOTFILE > /dev/null
exit 0
