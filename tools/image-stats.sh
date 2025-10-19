#!/bin/bash

# Script to collect image statistics from content/posts directory
# Collects: dimensions (width x height) and file sizes (KB/MB)

set -euo pipefail

DIR="content/posts"
OUTPUT_FILE="image-statistics.csv"
TEMP_FILE="/tmp/image-stats-temp.txt"

echo "🔍 Collecting image statistics from $DIR..."

# Create CSV header
echo "Filename,Width,Height,Pixels,FileSize_Bytes,FileSize_KB,FileSize_MB,Path" > "$OUTPUT_FILE"

# Initialize counters
total_images=0
total_size=0

# Process all images
find "$DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) 2>/dev/null | while read -r img; do
  # Get file size
  file_size=$(stat -f%z "$img" 2>/dev/null)
  file_size_kb=$(echo "scale=2; $file_size / 1024" | bc)
  file_size_mb=$(echo "scale=2; $file_size / 1024 / 1024" | bc)

  # Get image dimensions using sips
  width=$(sips -g pixelWidth "$img" 2>/dev/null | grep "pixelWidth:" | awk '{print $2}')
  height=$(sips -g pixelHeight "$img" 2>/dev/null | grep "pixelHeight:" | awk '{print $2}')

  # Calculate total pixels
  if [ -n "$width" ] && [ -n "$height" ]; then
    pixels=$((width * height))
  else
    width="N/A"
    height="N/A"
    pixels="N/A"
  fi

  # Get filename
  filename=$(basename "$img")

  # Write to CSV
  echo "$filename,$width,$height,$pixels,$file_size,$file_size_kb,$file_size_mb,$img" >> "$OUTPUT_FILE"

  total_images=$((total_images + 1))
  total_size=$((total_size + file_size))

  # Progress indicator
  if [ $((total_images % 100)) -eq 0 ]; then
    echo "  Processed $total_images images..."
  fi
done

# Calculate statistics
echo ""
echo "📊 Generating statistics..."

# Count images by size ranges
over_10mb=$(awk -F',' '$7 > 10' "$OUTPUT_FILE" | wc -l | xargs)
between_5_10mb=$(awk -F',' '$7 >= 5 && $7 < 10' "$OUTPUT_FILE" | wc -l | xargs)
between_1_5mb=$(awk -F',' '$7 >= 1 && $7 < 5' "$OUTPUT_FILE" | wc -l | xargs)
between_500kb_1mb=$(awk -F',' '$6 >= 500 && $7 < 1' "$OUTPUT_FILE" | wc -l | xargs)
between_100_500kb=$(awk -F',' '$6 >= 100 && $6 < 500' "$OUTPUT_FILE" | wc -l | xargs)
under_100kb=$(awk -F',' '$6 < 100' "$OUTPUT_FILE" | wc -l | xargs)

# Count images by dimension ranges
over_4k=$(awk -F',' '$2 > 3840 || $3 > 2160' "$OUTPUT_FILE" 2>/dev/null | wc -l | xargs)
over_1920=$(awk -F',' '($2 > 1920 || $3 > 1080) && ($2 <= 3840 && $3 <= 2160)' "$OUTPUT_FILE" 2>/dev/null | wc -l | xargs)
over_1200=$(awk -F',' '($2 > 1200 || $3 > 1200) && ($2 <= 1920 && $3 <= 1080)' "$OUTPUT_FILE" 2>/dev/null | wc -l | xargs)
under_1200=$(awk -F',' '$2 <= 1200 && $3 <= 1200 && $2 != "N/A"' "$OUTPUT_FILE" 2>/dev/null | wc -l | xargs)

# Get total count (excluding header)
total_count=$(($(wc -l < "$OUTPUT_FILE") - 1))

# Calculate total size
total_size_gb=$(awk -F',' 'NR>1 {sum+=$7} END {printf "%.2f", sum/1024}' "$OUTPUT_FILE")
total_size_mb=$(awk -F',' 'NR>1 {sum+=$7} END {printf "%.2f", sum}' "$OUTPUT_FILE")

# Calculate average
avg_size_mb=$(awk -F',' 'NR>1 {sum+=$7; count++} END {if(count>0) printf "%.2f", sum/count}' "$OUTPUT_FILE")

# Print summary
cat << EOF

===================================
📊 IMAGE STATISTICS SUMMARY
===================================

Total Images: $total_count
Total Size: ${total_size_gb} GB (${total_size_mb} MB)
Average Size: ${avg_size_mb} MB

FILE SIZE DISTRIBUTION:
  > 10 MB:        $over_10mb images
  5-10 MB:        $between_5_10mb images
  1-5 MB:         $between_1_5mb images
  500KB-1MB:      $between_500kb_1mb images
  100-500KB:      $between_100_500kb images
  < 100KB:        $under_100kb images

DIMENSION DISTRIBUTION:
  > 4K (3840x2160):     $over_4k images
  > Full HD (1920):     $over_1920 images
  > 1200px:             $over_1200 images
  ≤ 1200px:             $under_1200 images

TOP 10 LARGEST FILES:
EOF

# Show top 10 largest files
awk -F',' 'NR>1 {print $7, $1, $2"x"$3}' "$OUTPUT_FILE" | sort -rn | head -10 | awk '{printf "  %.2f MB - %s (%s)\n", $1, $2, $3}'

echo ""
echo "TOP 10 LARGEST DIMENSIONS:"
awk -F',' 'NR>1 && $2 != "N/A" {print $4, $1, $2"x"$3}' "$OUTPUT_FILE" | sort -rn | head -10 | awk '{printf "  %s pixels - %s (%s)\n", $1, $2, $3}'

echo ""
echo "✅ Detailed statistics saved to: $OUTPUT_FILE"
echo "   You can open it in Excel or any CSV viewer"
