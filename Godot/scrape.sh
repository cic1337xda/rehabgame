#!/bin/bash

output_file="Kod_Flappy_Bird.md"

# Bersihkan fail lama
> "$output_file"

echo "# Kod Sumber Flappy Bird" >> "$output_file"
echo "" >> "$output_file"

# Fungsi untuk tambah kandungan fail
add_file() {
  filepath=$1
  title=$2
  
  if [ -f "$filepath" ]; then
    echo "## $title" >> "$output_file"
    echo "\`\`\`gdscript" >> "$output_file"
    cat "$filepath" >> "$output_file"
    echo "\`\`\`" >> "$output_file"
    echo "" >> "$output_file"
  else
    echo "## $title" >> "$output_file"
    echo "*Fail tidak dijumpai: $filepath*" >> "$output_file"
    echo "" >> "$output_file"
  fi
}

# Senarai fail yang nak disatukan
add_file "games/flappy_bird/scripts/main.gd" "main.gd"
add_file "games/flappy_bird/scripts/bird.gd" "bird.gd"
add_file "games/flappy_bird/scripts/pipe.gd" "pipe.gd"
add_file "games/flappy_bird/scripts/ground.gd" "ground.gd"
add_file "games/flappy_bird/scripts/game_over.gd" "game_over.gd"

echo "Selesai! Buka fail $output_file"
