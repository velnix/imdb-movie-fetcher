#!/bin/bash
#Movie fetcher
#Movie data fetcher developed by Unni <unnikrishnan.a@gmail.com>
#Code to fetch poster, machine readable output and bug fixes by
#Mikhail Fedotov <anyremote@mail.ru>
#Contribution for version 5 from zzarko@gmail.com
#version 5
shopt -s -o nounset
#Global variable declarations
declare -rx MYSITE="https://www.velnix.com/projects/"
declare -rx SOURCE_REPO="https://github.com/velnix/imdb-movie-fetcher"
declare -rx SCRIPT=${0##*/}
declare -rx VERSION="5"
declare URL
declare TITLE
declare OTITLE=""
declare YEAR
declare RATING
declare PLOT
declare MOVIE
declare MYEAR=""
declare POSTER=0
declare GOOGLE=0
declare DUCK=0
declare IMDBID=0
declare PARSEABLE=0
declare SIMILAR=1
declare DIRECTOR
declare GENRE
declare CAST
declare POSTERURL
declare -rx TMPFILE=/tmp/imdbmoviefetcher.$$
declare -rx PLOTFILE=/tmp/plot.$$.html
declare -rx LYNX="/usr/bin/lynx"
declare -rx SED="/bin/sed"
declare -rx EGREP="/bin/egrep"
declare -rx GREP="/bin/grep"
declare SWITCH
declare -r OPTSTRING=":hvpmsgdt:y:i:"
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
#End of colorse function

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

#check the input arguments/ parametrs
if [ $# -eq 0 ]
then
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
   -y [arg] : Pass the movie year title as argument.
   -p : Download movie poster. Use it with -t option.
   -s : Do not show similar titles.
   -g : Only search with Google for IMDB ID, don't search IMDB.
   -d : Only search with DuckDuckGo for IMDB ID, don't search IMDB.
   -i [arg] : Pass the IMDB ID, skip Google
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
y) MYEAR="+$OPTARG"
   ;;
p) POSTER="1"
   ;;
s) SIMILAR="0"
   ;;
g) GOOGLE="1"
   ;;
d) DUCK="1"
   ;;
i) IMDBID="$OPTARG"
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

if [[ "$IMDBID" == "0" && "$DUCK" == "0" ]]; then
    [[ ${MOVIE:-unset} == 'unset' || -z $MOVIE ]] && { printf "Invalid input. Execute %s -h for more information\n" "$SCRIPT";exit 192;}
fi

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

if [ "$IMDBID" == "0" ]; then
    #replace special characters in the movie name argument
    MOVIE=`echo $MOVIE | sed -r 's/  */\+/g;s/\&/%26/g;s/\++$//g'`
    if [ "$DUCK" == "0" ]; then
        #search the title in google
        #URL="http://www.google.com/search?hl=en&q=\"$MOVIE\"$MYEAR+imdb"
        URL="https://www.google.com/search?client=ubuntu&channel=fs&q=$MOVIE$MYEAR+imdb&ie=utf-8&oe=utf-8"
        $LYNX -connect_timeout=10 --source $URL > $TMPFILE 2> /dev/null
        #Check if lynx is successful
        if [ $? -ne 0 ]
        then 
          printf "Connection to site failed...Please check your internet connection\n"
          exit 192
        fi
        #check if robot detected
        ROBOT=`$EGREP -o "detected unusual traffic" $TMPFILE | head -1`
        if [ "$ROBOT" == "detected unusual traffic" ]; then
            echo "Google detected unusual traffic!!"
            DUCK="1"
        else
            #Get IMDB URL for the film
            URL=`$EGREP -o "http://www.imdb.com/title/tt[0-9]*/" $TMPFILE | head -1`
            #Get similar titles
            SIMILARTITLES=`egrep -o "<a[^>]+>[^<]*(<b>[^<|^(imdb)]+</b>)*[^<]*<b>[^<]*</b>[^\(|^<]*\([0-9]+\)[^-]+-[^<]*<b>IMDb</b>" $TMPFILE | grep "www.imdb.com" | sort | uniq | sed 's/- <b>IMDb<\/b>//g' | sed 's/<[^>]*>//g'`
        fi
    fi
    if [ "$DUCK" == "1" ]; then
        #search the title in duckduckgo
        URL="https://duckduckgo.com/?q=$MOVIE$MYEAR+imdb"
        $LYNX -connect_timeout=10 --source $URL > $TMPFILE 2> /dev/null
        #Check if lynx is successful
        if [ $? -ne 0 ]
        then 
          printf "Connection to site failed...Please check your internet connection\n"
          exit 192
        fi
        #check if robot detected
        ROBOT=`$EGREP -o "detected unusual traffic" $TMPFILE | head -1`
        if [ "$ROBOT" == "detected unusual traffic" ]; then
            echo "DuckDuck detected unusual traffic"
            exit 192
        fi
        #Get IMDB URL for the film
        URL=`$EGREP -o "tt[0-9]{4,15}" $TMPFILE | head -1`
        URL="http://www.imdb.com/title/$URL/"
    fi
else
    URL="http://www.imdb.com/title/$IMDBID/"
    SIMILARTITLES=""
fi

if [ "$GOOGLE" == "1" ]; then
    echo `echo "$URL" | $EGREP -o "tt[0-9]+"`
    exit 0
fi

#get the details from movie page
$LYNX --source ${URL} > $TMPFILE;
if [ $? -ne 0 ]
then 
  printf "Connection to site failed...Please check your internet connection\n"
  exit 192
fi

#extract data
#YEAR=`cat $TMPFILE | $SED -n '/<h1.*>/,/<\/h1>/p' | $SED -n '/<span.*>/,/<\/span>/p' | $SED '/^$/d;s/<[^>]*>//g;s/(//g;s/)//g' | $SED 's/&ndash;/ - /g'| $EGREP -o "[0-9][0-9][0-9][0-9]( - [0-9][0-9][0-9][0-9])*"`
#TITLE=`cat $TMPFILE | $SED -n '/<h1.*>/,/<\/h1>/p' | $SED '1d;$d;/^$/d;s/<[^>]*>//g;s/(//g;s/)//g' | head -1 | $SED "s/\&#x27\;/\'/g"`

TITLE=`cat $TMPFILE | $SED -n '/<h1.*>/,/<\/h1>/p' | $SED -n 's/.*itemprop="name">//;s/<.*//p' | head -1 | tr -s ' ' | tr '\n' ' '`
TITLE=`echo $TITLE`
YEAR=`cat $TMPFILE | $SED -n '/<h1.*>/,/<\/h1>/p' | $SED -n '/<span class="nobr".*>/,/<\/span>/p' | $SED '/^$/d;s/<[^>]*>//g;s/(//g;s/)//g' | $SED 's/&ndash;/ - /g;/[^"]"/d;s/>//g' | grep -o -E "[0-9]{4}"`
OTITLE=`cat $TMPFILE | $SED -n '/<span class="title-extra.*>/,/<\/span>/p' | $SED '/^$/d;s/<[^>]*>//g;s/(//g;s/)//g' | $SED -n '/".*"/p' | tr -d '"' | $SED -e 's/^[ \t]*//'`
#if [[ "$YEAR" == *original* ]]; then
#    OTITLE=${YEAR#*\"}
#    OTITLE=${OTITLE%\"*}
#    YEAR=${YEAR//$'\n'/Y}
#    YEAR=${YEAR%%Y*}
#fi
YEAR=`echo $YEAR|tr -d ' '`

POSTERURL=`grep "Poster" $TMPFILE -A1|grep -o http.*\.jpg|cut -f 1 -d "_"`
POSTERURL=${POSTERURL}jpg

if [ $POSTER -eq 1 ] 
then
  POSTERFILE=`echo $TITLE | $SED "s/ /_/g"`
  $LYNX -connect_timeout=10 --source $POSTERURL > ${POSTERFILE}.jpg 2> /dev/null
fi

RATING=`$SED -n '/<span itemprop="ratingValue">/{ s/<[^>]*>//g;p;}' $TMPFILE  | $EGREP -o "[0-9]+\.[0-9]+/[0-9]+" | tail -1`;

#Get the plot in a html file
#$SED -n '/<h1.*>/,/<\/p>/p' $TMPFILE | $SED -n '/<p>/,/<\/p>/{ s/<[^>]*>//g;p;}' | $SED 's/See full summary.*//g' > $PLOTFILE 
$SED -n '/.*<p itemprop="description">/,/<\/p>/p' $TMPFILE | $SED -n 's/.*itemprop="description">//;s/<[^>]*>//pg' > $PLOTFILE 
PLOT=`lynx --dump $PLOTFILE | sed 's/^  *//g'`

#DIRECTOR=`$SED -n '/ *Director[s]*:.*/,/ *Writer[s]*:.*/{p;}' $TMPFILE | $SED -n '/ *Director[s]*:.*/,/ *Star[s]*:.*/{p;}' | $SED '1d;$d' | tr '\n' ' ' | $SED 's/<[^>]*>//g;s/^ *//g;s/ *$//g;s/&nbsp;&raquo;//g'`
#GENRE=`$SED -n '/genre/p' $TMPFILE | $EGREP -o '<a  *.*href="/genre/[a-zA-Z][a-z]*"[^>]*>[^<]*</a>' | $SED 's/<[^>]*>//g;s/&nbsp\;//g;s/ *Genres *[0-9][0-9]* *min-//g;s/|/,/g' | $SED 's/[gG]enres//g;s/^  *//g' | uniq | head -1`
#CAST=`$SED -n '/.*Star[s]*:.*/,/<\/div>/{ s/<[^>]*>//g;s/Stars://g;p }' $TMPFILE | grep -v "See full cast and crew" | $SED -n '/^ *$/d;p' | tr '\n' ' ' | $SED 's/<[^>]*>//g;s/|//g'`

DIRECTOR=`$SED -n '/ *itemprop="director.*/,/<\/div>/{p;}' $TMPFILE|$SED -n 's/.*itemprop="name">//;s/<.*//p'|uniq|tr -s ' '|tr '\n' ','|sed 's/ ,//g;s/^,//;s/,$//'`
GENRE=`grep "ref_=tt_ov_inf" $TMPFILE | grep genre | $SED -n 's/<a href="\/genre\///p' | $SED -n 's/?ref_=tt_ov_inf"//p' | uniq | tr '\n' ',' | sed 's/^,//;s/,$//'`
CAST=`$SED -n '/ *tt_ov_st.*/,/tt_ov_st_sm/{p;}' $TMPFILE|$SED -n 's/.*itemprop="name">//;s/<.*//p'|uniq|tr -s ' '|tr '\n' ','|sed 's/ ,//g;s/,,/,/g;s/^,//;s/,$//'`

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
printf "${COLOR_START}${TITLE_COLOR_TAG}Title${COLOR_END}      : ${COLOR_START}${DATA_COLOR_TAG}$TITLE${COLOR_END}\n"
if [ "$OTITLE" != "" ]; then
    printf "${COLOR_START}${TITLE_COLOR_TAG}Original${COLOR_END}   : ${COLOR_START}${DATA_COLOR_TAG}$OTITLE${COLOR_END}\n"
fi
printf "${COLOR_START}${TITLE_COLOR_TAG}Year${COLOR_END}       : ${COLOR_START}${DATA_COLOR_TAG}$YEAR${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Rating${COLOR_END}     : ${COLOR_START}${DATA_COLOR_TAG}$RATING${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Director${COLOR_END}   : ${COLOR_START}${DATA_COLOR_TAG}$DIRECTOR${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Genres${COLOR_END}     : ${COLOR_START}${DATA_COLOR_TAG}$GENRE${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Cast${COLOR_END}       : ${COLOR_START}${DATA_COLOR_TAG}$CAST${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Plot${COLOR_END}       : ${COLOR_START}${DATA_COLOR_TAG}%s${COLOR_END}\n" "$PLOT"
printf "\n${COLOR_START}${TITLE_COLOR_TAG}IMDB movie URL${COLOR_END} : ${COLOR_START}${LINK_COLOR_TAG}${URL}${COLOR_END}\n"
printf "${COLOR_START}${TITLE_COLOR_TAG}Poster URL${COLOR_END} : ${COLOR_START}${LINK_COLOR_TAG}${POSTERURL}${COLOR_END}"

if [ $SIMILAR -eq 1 ] 
then
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
      printf "%s" "$SIMILARTITLES" > $TMPFILE.sim
      cat $TMPFILE.sim|xargs -i echo "Similarities : "{}
      rm -f $TMPFILE.sim > /dev/null   
    fi
  fi
fi

#Done. Now do cleanup
rm $TMPFILE > /dev/null
rm $PLOTFILE > /dev/null
exit 0

