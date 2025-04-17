#!/bin/bash

# This script installs the bash tips and tricks collection

# Supported languages
languages=("french" "english")

# Supported technologies
technologies=("bash")


# echo "Select a language:"
# select lang in "${languages[@]}"; do
#     if [[ " ${languages[@]} " =~ " ${lang} " ]]; then
#         echo "You selected: $lang"
#         break
#     else
#         echo "Invalid selection. Please try again."
#     fi
# done



# strfile tips/french/bash/*.txt > /dev/null
for dir in tips/*/; do
    for dir2 in "$dir"/*/; do
        for file in "$dir2"*.txt; do
            if [ -f "$file" ]; then
                strfile "$file" > /dev/null
            fi
        done
    done
done

#create the app folder

if [ ! -d ~/.term_tips ]; then
    mkdir ~/.term_tips
fi
#copy the tips and tricks to the app folder
cp -r tips/* ~/.term_tips/ ;
cp ./uninstall.sh ~/.term_tips/ ;
chmod +x ~/.term_tips/uninstall.sh ;

#register the version of the install

if ! command -v jq &> /dev/null
then
    echo "jq could not be found, please install it to check for updates"
    echo "0.0.0" > ~/.term_tips/version
else
git=https://api.github.com/repos/MonsieurCo/cowtips/releases/latest
tag= eval "curl -s $git| jq -r '.tag_name' " >> ~/.term_tips/version
fi


if [[ ! " ${languages[@]} " =~ " $1 " ]]; then
    echo "Language not supported. Supported languages are: ${languages[*]}"
    exit 1
fi
if [[ ! " ${technologies[@]} " =~ " $2 " ]]; then
    echo "Technology not supported. Supported technologies are: ${technologies[*]}"
    exit 1
fi


command="~/.term_tips/cowtips.sh $1 $2;"

if ! grep -q "cowtips.sh"  ~/.profile ; then
    echo $command >> ~/.profile ;
    echo "alias cowtips='~/.term_tips/cowtips.sh'" >> ~/.profile;
    echo $1 $2 > ~/.term_tips/config;
    
    cowsay "Bash tips and tricks collection installed :)";
else
    cowsay "The fortune command is already added to ~/.profile ! "
fi
