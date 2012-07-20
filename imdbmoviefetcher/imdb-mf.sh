#!/bin/bash
#IMDB Movie fetcher
#an IMDB movie data fetcher developed by Unnikrishnan.A
#unnikrishnan.a@gmail.com
#http://imdbmoviefetche.sourceforge.net/
#version 4.0
shopt -s -o nounset
#Global variable declarations
declare -rx MYSITE="http://imdbmoviefetche.sourceforge.net/"
declare -rx SCRIPT=${0##*/}
declare -rx VERSION="4.0"
declare URL
declare TITLE
declare YEAR
declare RATING
declare PLOT
declare MOVIE
declare DIRECTOR
declare GENRE
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
declare -rx SORT="/usr/bin/sort"
declare SWITCH
declare -r OPTSTRING=":hvt:"
declare -i INEEDCOLOR
declare TITLECOLOR="White"
declare DATACOLOR="White"
declare LINKCOLOR="White"
declare CONFFILE="/etc/imdb-mf.conf"
#Get color for colorised output
if [ -f $HOME/.imdb-mf.conf ]
then
CONFFILE=$HOME/.imdb-mf.conf 
fi
if [ ! -f $CONFFILE ]
then 
echo "Not able to see the conf file at $CONFFILE. Create it!!"
exit 192
fi
INEEDCOLOR=0
. $CONFFILE
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
TITLECOLOR="White"
DATACOLOR="White"
LINKCOLOR="White"
getcolor $TITLECOLOR TITLECOLOR
getcolor $DATACOLOR DATACOLOR
getcolor $LINKCOLOR LINKCOLOR
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
   $SCRIPT [option] [arg]

   Options : 
   -v : gives the version of the script
   -h : shows the help page
   -t [arg] : Pass the movie title as argument. It is recommended to quote the name as shown in the example below 

   Example : 
   $SCRIPT -t "startship troopers"
 
   Bugs, feature requests etc : $MYSITE

EOF
   exit 0
   ;;
t) MOVIE="$OPTARG"
   ;;
v) printf "IMDB movie fetcher version %s.\nBugs, Feature requests etc : %s\n" "$VERSION" "$MYSITE"
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
sancheck $LYNX
sancheck $CAT
sancheck $EGREP
sancheck $GREP
sancheck $UNIQ
sancheck $HEAD
sancheck $SED
sancheck $SORT
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
SIMILARTITLES=`egrep -o "<a[^>]+>[^<]*(<em>[^<|^(imdb)]+</em>)*[^<]*<em>[^<]*</em>[^\(|^<]*\([0-9]+\)[^-]+-[^<]*<em>IMDb</em>" $TMPFILE | grep "www.imdb.com" | sort | uniq | sed 's/- <em>IMDb<\/em>//g' | sed 's/<[^>]*>//g'`
#get the details from movie page
$LYNX --source ${URL} > $TMPFILE;
if [ $? -ne 0 ]
then 
printf "Connection to site failed...Please check your internet connection\n"
exit 192
fi
#extract data
YEAR=`$CAT $TMPFILE | $SED -n '/<h1.*>/,/<\/h1>/p' | $SED '1d;$d;/^$/d;s/<[^>]*>//g;s/(//g;s/)//g' | $EGREP -o "[0-9][0-9][0-9][0-9]"`
TITLE=`$CAT $TMPFILE | $SED -n '/<h1.*>/,/<\/h1>/p' | $SED '1d;$d;/^$/d;s/<[^>]*>//g;s/(//g;s/)//g' | $HEAD -1 | $SED "s/\&#x27\;/\'/g" | $LYNX -stdin -dump -nomargins`
#Get the plot in a html file
$SED -n '/<h1.*>/,/<\/p>/p' $TMPFILE | $SED -n '/<p>/,/<\/p>/{ s/<[^>]*>//g;p;}' | $SED 's/See full summary.*//g' > $PLOTFILE 
PLOT=`lynx --dump $PLOTFILE | sed 's/^  *//g'`
RATING=`$SED -n '/<span itemprop="ratingValue">/{ s/<[^>]*>//g;p;}' $TMPFILE  | $EGREP -o "[0-9]+\.[0-9]+/[0-9]+" | tail -1`;
DIRECTOR=`$SED -n '/ *Director[s]*:.*/,/ *Writer[s]*:.*/{p;}' $TMPFILE | $SED '1d;$d' | tr '\n' ' ' | $SED 's/<[^>]*>//g' | $SED 's/^ *//g;s/ *$//g'`
GENRE=`$SED -n '/genre/p' $TMPFILE | $EGREP -o '<a  *.*href="/genre/[a-zA-Z][a-z]*"[^>]*>[^<]*</a>' | $SED 's/<[^>]*>//g;s/&nbsp\;//g;s/ *Genres *[0-9][0-9]* *min-//g;s/|/,/g' | $SED 's/[gG]enres//g;s/^  *//g' | $UNIQ | $HEAD -1`
CAST=`$SED -n '/.*Star[s]*:.*/,/<\/div>/{ s/<[^>]*>//g;s/Stars://g;p }' $TMPFILE | $SED -n '/^ *$/d;p' | tr '\n' ' ' | $SED 's/<[^>]*>//g'`
#print everything
printf "\n\033[${TITLECOLOR_MODE};${TITLECOLOR_CODE}mTitle\033[0m      : \033[${DATACOLOR_MODE};${DATACOLOR_CODE}m$TITLE\033[0m\n"
printf "\033[${TITLECOLOR_MODE};${TITLECOLOR_CODE}mYear\033[0m       : \033[${DATACOLOR_MODE};${DATACOLOR_CODE}m$YEAR\033[0m\n"
printf "\033[${TITLECOLOR_MODE};${TITLECOLOR_CODE}mRating\033[0m     : \033[${DATACOLOR_MODE};${DATACOLOR_CODE}m$RATING\033[0m\n"
printf "\033[${TITLECOLOR_MODE};${TITLECOLOR_CODE}mDirector\033[0m   : \033[${DATACOLOR_MODE};${DATACOLOR_CODE}m$DIRECTOR\033[0m\n"
printf "\033[${TITLECOLOR_MODE};${TITLECOLOR_CODE}mGenres\033[0m     : \033[${DATACOLOR_MODE};${DATACOLOR_CODE}m$GENRE\033[0m\n"
printf "\033[${TITLECOLOR_MODE};${TITLECOLOR_CODE}mCast\033[0m       : \033[${DATACOLOR_MODE};${DATACOLOR_CODE}m$CAST\033[0m\n"
printf "\033[${TITLECOLOR_MODE};${TITLECOLOR_CODE}mPlot\033[0m       :\n\n\033[${DATACOLOR_MODE};${DATACOLOR_CODE}m%s\033[0m\n\n" "$PLOT"
printf "\033[${TITLECOLOR_MODE};${TITLECOLOR_CODE}mIMDB movie URL\033[0m : \033[${LINKCOLOR_MODE};${LINKCOLOR_CODE}m${URL}\033[0m\n\n"
printf "\033[${TITLECOLOR_MODE};${TITLECOLOR_CODE}m==============Other similar Titles=============\033[0m\n\n"
if [ -z "$SIMILARTITLES" ]
then
SIMILARTITLES="Nothing interesting here"
fi
printf "\033[${DATACOLOR_MODE};${DATACOLOR_CODE}m%s\033[0m\n\n" "$SIMILARTITLES"
printf "\033[${TITLECOLOR_MODE};${TITLECOLOR_CODE}mUse above key words to know more about them\033[0m\n\n"
#Done. Now do cleanup
rm $TMPFILE > /dev/null
rm $PLOTFILE > /dev/null
exit 0
