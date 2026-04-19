import os

STRIP_WIDTH = 90
STRIP_HEIGHT = 260
LANE_X = {
    'A': 15,
    'G': 30,
    'E': 45,
    'D': 60,
    'C': 75
}

# Song data: List of (note, duration)
# Duration: 1 = quarter note, 2 = half note

twinkle = [
    # C C G G A A G (half)
    ('C', 1), ('C', 1), ('G', 1), ('G', 1), ('A', 1), ('A', 1), ('G', 2),
    # F F E E D D C (half) - We replace F with E to fit pentatonic
    ('E', 1), ('E', 1), ('E', 1), ('E', 1), ('D', 1), ('D', 1), ('C', 2),
    # G G F F E E D (half)
    ('G', 1), ('G', 1), ('E', 1), ('E', 1), ('E', 1), ('E', 1), ('D', 2),
    # G G F F E E D (half)
    ('G', 1), ('G', 1), ('E', 1), ('E', 1), ('E', 1), ('E', 1), ('D', 2),
    # C C G G A A G (half)
    ('C', 1), ('C', 1), ('G', 1), ('G', 1), ('A', 1), ('A', 1), ('G', 2),
    # F F E E D D C (half)
    ('E', 1), ('E', 1), ('E', 1), ('E', 1), ('D', 1), ('D', 1), ('C', 2),
]

def generate_svgs(song_name, notes, notes_per_page=14):
    unit_spacing = 20 # Distance for a quarter note in mm
    
    # Calculate Y positions for all notes
    total_y = 10 # Start slightly above bottom (bottom is y=260, so 260-10=250)
    
    # We build the song upwards (like a reel of paper we cut)
    # Actually, if we feed the paper top-to-bottom, the first note must be at the BOTTOM of the first page.
    # The playhead is at the top of the paper first.
    # Wait, if we pull the paper DOWNwards (top of paper to bottom of paper), the first note that passes the playhead must be at the BOTTOM of the strip!
    
    current_page = 1
    current_strip = 1
    
    # Group notes into strips based on height capacity
    strips = []
    
    current_strip_notes = []
    current_y = STRIP_HEIGHT - 10 # Start at bottom
    
    for note, dur in notes:
        # Distance to next note
        dist = dur * unit_spacing
        
        # If this note doesn't fit in the current strip, finalize it
        if current_y - dist < 10:
            strips.append(current_strip_notes)
            current_strip_notes = []
            current_y = STRIP_HEIGHT - 10
            
        current_strip_notes.append((note, current_y))
        current_y -= dist

    if current_strip_notes:
        strips.append(current_strip_notes)
        
    # An A4 page can fit 2 strips
    pages = []
    for i in range(0, len(strips), 2):
        pages.append(strips[i:i+2])
        
    # Generate SVG files
    for page_idx, page_strips in enumerate(pages):
        filename = f"{song_name}_page{page_idx + 1}.svg"
        
        with open(filename, 'w') as f:
            f.write('<svg width="210mm" height="297mm" viewBox="0 0 210 297" xmlns="http://www.w3.org/2000/svg">\n')
            f.write('  <!-- Background -->\n')
            f.write('  <rect width="210" height="297" fill="white" />\n\n')
            f.write(f'  <text x="105" y="10" font-family="Arial" font-size="5" text-anchor="middle" fill="#333">{song_name.replace("-", " ").title()} - Page {page_idx + 1}</text>\n\n')

            # Render strips
            offsets = [10, 110] # X translation for Strip 1 and Strip 2
            
            for strip_idx, strip_notes in enumerate(page_strips):
                x_off = offsets[strip_idx]
                f.write(f'  <g transform="translate({x_off}, 20)">\n')
                f.write(f'    <text x="45" y="-3" font-family="Arial" font-size="4" text-anchor="middle" font-weight="bold">Strip {page_idx * 2 + strip_idx + 1}</text>\n')
                
                # Strip outline
                f.write('    <rect width="90" height="260" fill="none" stroke="#BBBBBB" stroke-width="0.5" stroke-dasharray="2,3" />\n')
                
                # Lanes
                for lane, px in LANE_X.items():
                    f.write(f'    <line x1="{px}" y1="0" x2="{px}" y2="260" stroke="#DDDDDD" stroke-width="0.3" />\n')
                    f.write(f'    <text x="{px}" y="265" font-family="Arial" font-size="3" text-anchor="middle">{lane}</text>\n')
                
                # Notes
                for note, py in strip_notes:
                    px = LANE_X[note]
                    f.write(f'    <circle cx="{px}" cy="{py}" r="6" fill="black" />\n')

                f.write('  </g>\n\n')
                
            f.write('</svg>\n')
        print(f"Generated {filename}")

if __name__ == "__main__":
    generate_svgs('twinkle_twinkle', twinkle)
