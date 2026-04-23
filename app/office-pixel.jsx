// Office Pixel — canvas renderer with Ascenda OS palette (navy/emerald/sky)
// Light glass background, rich decoration, department drill-down support.

const { useRef: useOfRef, useEffect: useOfEffect, useState: useOfState, useCallback: useOfCallback } = React;

// ————— Ascenda OS theme — light glass + navy + emerald —————
const THEME = {
  // Ascenda brand palette (from logo)
  navy:      '#1E40AF',
  navyDk:    '#0F1F4A',
  navyMid:   '#1E3A8A',
  navyLt:    '#3B82F6',
  emerald:   '#10B981',
  emeraldDk: '#059669',
  emeraldLt: '#34D399',
  sky:       '#0EA5E9',
  // Surfaces (light)
  bgSoft:    '#EEF2FA',   // the pale blue-ish tint of Ascenda hero
  bgPaper:   '#F8FAFC',
  paper:     '#FFFFFF',
  ink:       '#0F172A',
  mute:      '#64748B',
  line:      '#E2E8F0',
  lineSoft:  '#F1F5F9',
  // Floor palettes — LIGHT TONES
  woodLt:    '#F5E6D3',   // warm parquet
  woodMid:   '#E8D5B7',
  woodDk:    '#D4B896',
  tileLt:    '#F8FAFC',   // cool office tile
  tileDk:    '#E2E8F0',
  // Department carpets (soft pastel tints aligned with dept color)
  carpet: {
    navy:    ['#DBEAFE', '#BFDBFE'],   // executive
    blue:    ['#DBEAFE', '#C7D7FA'],   // marketing
    emerald: ['#D1FAE5', '#A7F3D0'],   // finance, research
    sky:     ['#E0F2FE', '#BAE6FD'],   // callcenter
    azul:    ['#DBEAFE', '#BFDBFE'],   // sales
    teal:    ['#CCFBF1', '#99F6E4'],   // hr
    cyan:    ['#CFFAFE', '#A5F3FC'],   // scheduler, accounting
    slate:   ['#E0E7FF', '#C7D2FE'],   // legal
    cafe:    ['#FEF3C7', '#FDE68A'],   // cafeteria warm
  },
  wall:      '#CBD5E1',
  wallDk:    '#94A3B8',
};

// Map department → carpet palette key
const DEPT_CARPET = {
  executive:  'navy',
  marketing:  'blue',
  finance:    'emerald',
  callcenter: 'sky',
  sales:      'azul',
  hr:         'teal',
  scheduler:  'cyan',
  research:   'emerald',
  accounting: 'cyan',
  legal:      'slate',
  cafe:       'cafe',
  meeting:    'slate',
};

// ————— Floor drawing —————
function drawFloor(ctx, zone, tile) {
  const { x, y, w, h, dept } = zone;
  const px = x * tile, py = y * tile;
  const pw = w * tile, ph = h * tile;

  if (zone.floor === 'wood' || dept === 'cafe' || dept === 'meeting') {
    // Parquet — light warm wood
    for (let i = 0; i < h; i++) {
      for (let j = 0; j < w; j++) {
        const alt = (Math.floor(i / 1) + Math.floor(j / 2)) % 2 === 0;
        ctx.fillStyle = alt ? THEME.woodLt : THEME.woodMid;
        ctx.fillRect(px + j * tile, py + i * tile, tile, tile);
      }
    }
    // Plank seams
    ctx.strokeStyle = 'rgba(139, 92, 46, 0.15)';
    ctx.lineWidth = 1;
    for (let i = 1; i < h; i++) {
      ctx.beginPath();
      ctx.moveTo(px, py + i * tile + 0.5);
      ctx.lineTo(px + pw, py + i * tile + 0.5);
      ctx.stroke();
    }
    return;
  }

  // Tinted tile for departments
  const carpetKey = DEPT_CARPET[dept];
  const palette = THEME.carpet[carpetKey] || [THEME.tileLt, THEME.tileDk];
  const [c1, c2] = palette;

  for (let i = 0; i < h; i++) {
    for (let j = 0; j < w; j++) {
      const alt = (i + j) % 2 === 0;
      ctx.fillStyle = alt ? c1 : c2;
      ctx.fillRect(px + j * tile, py + i * tile, tile, tile);
    }
  }
  // Subtle grid
  ctx.strokeStyle = 'rgba(15, 23, 42, 0.04)';
  ctx.lineWidth = 1;
  for (let j = 0; j <= w; j++) {
    ctx.beginPath();
    ctx.moveTo(px + j * tile + 0.5, py);
    ctx.lineTo(px + j * tile + 0.5, py + ph);
    ctx.stroke();
  }
  for (let i = 0; i <= h; i++) {
    ctx.beginPath();
    ctx.moveTo(px, py + i * tile + 0.5);
    ctx.lineTo(px + pw, py + i * tile + 0.5);
    ctx.stroke();
  }
}

function drawZoneWalls(ctx, zone, tile) {
  const { x, y, w, h, dept } = zone;
  const deptColor = window.DEPARTMENTS[dept]?.color || THEME.wallDk;
  const px = x * tile, py = y * tile;
  const pw = w * tile, ph = h * tile;

  // Thin dept-colored border
  ctx.fillStyle = deptColor + '80';
  ctx.fillRect(px - 1, py - 1, pw + 2, 1);
  ctx.fillRect(px - 1, py + ph, pw + 2, 1);
  ctx.fillRect(px - 1, py - 1, 1, ph + 2);
  ctx.fillRect(px + pw, py - 1, 1, ph + 2);
  // Corners: solid dept dot
  ctx.fillStyle = deptColor;
  ctx.fillRect(px - 2, py - 2, 3, 3);
  ctx.fillRect(px + pw - 1, py - 2, 3, 3);
  ctx.fillRect(px - 2, py + ph - 1, 3, 3);
  ctx.fillRect(px + pw - 1, py + ph - 1, 3, 3);
}

// ————— Furniture —————
function drawDesk(ctx, desk, tile) {
  const px = desk.x * tile, py = desk.y * tile;
  // Desk body (light wood)
  ctx.fillStyle = '#E8D5B7';
  ctx.fillRect(px + 1, py + 2, tile - 2, tile - 8);
  ctx.fillStyle = '#D4B896';
  ctx.fillRect(px + 1, py + tile - 7, tile - 2, 2);  // front edge shadow
  // Monitor arm
  ctx.fillStyle = '#64748B';
  ctx.fillRect(px + tile/2 - 1, py + 4, 2, 4);
  // Monitor
  ctx.fillStyle = '#0F172A';
  ctx.fillRect(px + 4, py + 2, tile - 8, 8);
  ctx.fillStyle = '#1E293B';
  ctx.fillRect(px + 5, py + 3, tile - 10, 1);
  // Screen content — app-like
  ctx.fillStyle = THEME.navy;
  ctx.fillRect(px + 5, py + 4, tile - 10, 6);
  ctx.fillStyle = THEME.emerald;
  ctx.fillRect(px + 6, py + 5, 3, 1);
  ctx.fillStyle = '#60A5FA';
  ctx.fillRect(px + 10, py + 5, 5, 1);
  ctx.fillStyle = '#93C5FD';
  ctx.fillRect(px + 6, py + 7, 8, 1);
  ctx.fillRect(px + 6, py + 9, 6, 1);
  // Keyboard + mousepad
  ctx.fillStyle = '#F1F5F9';
  ctx.fillRect(px + 4, py + 13, tile - 8, 3);
  ctx.fillStyle = '#CBD5E1';
  ctx.fillRect(px + 4, py + 13, tile - 8, 1);
  // Coffee cup (random desks)
  if ((desk.x + desk.y) % 3 === 0) {
    ctx.fillStyle = '#fff';
    ctx.fillRect(px + tile - 5, py + 12, 3, 3);
    ctx.fillStyle = '#78350F';
    ctx.fillRect(px + tile - 4, py + 12, 1, 1);
  }
}

function drawChair(ctx, x, y, facing, tile, color = '#1E40AF') {
  const px = x * tile, py = y * tile;
  const cy = facing === 'down' ? py + tile + 2 : py - 6;
  // seat
  ctx.fillStyle = color;
  ctx.fillRect(px + 4, cy, tile - 8, 4);
  // back
  if (facing === 'down') {
    ctx.fillStyle = color;
    ctx.fillRect(px + 4, cy + 4, tile - 8, 2);
    ctx.fillStyle = 'rgba(0,0,0,0.2)';
    ctx.fillRect(px + 4, cy + 3, tile - 8, 1);
  } else {
    ctx.fillStyle = color;
    ctx.fillRect(px + 4, cy - 2, tile - 8, 2);
  }
  // wheel base
  ctx.fillStyle = '#1F2937';
  ctx.fillRect(px + tile/2 - 2, cy + (facing === 'down' ? 6 : -4), 4, 1);
}

function drawPlant(ctx, x, y, tile, variant = 0) {
  const px = x * tile, py = y * tile;
  // Pot (terracotta or white modern)
  if (variant === 0) {
    ctx.fillStyle = '#DC7A4C';
    ctx.fillRect(px + 6, py + 15, tile - 12, 6);
    ctx.fillStyle = '#C66A3C';
    ctx.fillRect(px + 6, py + 15, tile - 12, 1);
    ctx.fillStyle = 'rgba(0,0,0,0.15)';
    ctx.fillRect(px + 6, py + 20, tile - 12, 1);
  } else {
    ctx.fillStyle = '#fff';
    ctx.fillRect(px + 6, py + 15, tile - 12, 6);
    ctx.fillStyle = '#E2E8F0';
    ctx.fillRect(px + 6, py + 15, tile - 12, 1);
  }
  // Leaves — lush multi-layer
  ctx.fillStyle = '#065F46';
  ctx.fillRect(px + 5, py + 8, tile - 10, 7);
  ctx.fillStyle = '#047857';
  ctx.fillRect(px + 7, py + 4, tile - 14, 10);
  ctx.fillStyle = '#059669';
  ctx.fillRect(px + 4, py + 6, 4, 8);
  ctx.fillRect(px + tile - 8, py + 6, 4, 8);
  ctx.fillStyle = '#10B981';
  ctx.fillRect(px + 9, py + 2, tile - 18, 8);
  ctx.fillStyle = '#34D399';
  ctx.fillRect(px + 10, py + 4, 3, 3);
  ctx.fillRect(px + tile - 13, py + 6, 2, 2);
}

function drawLargePlant(ctx, x, y, tile) {
  const px = x * tile, py = y * tile;
  // Big planter
  ctx.fillStyle = '#FFFFFF';
  ctx.fillRect(px + 3, py + 16, tile - 6, tile - 18);
  ctx.fillStyle = '#E2E8F0';
  ctx.fillRect(px + 3, py + 16, tile - 6, 1);
  // Fronds
  ctx.fillStyle = '#064E3B';
  ctx.fillRect(px + 2, py + 8, tile - 4, 10);
  ctx.fillStyle = '#065F46';
  ctx.fillRect(px, py + 10, tile, 6);
  ctx.fillStyle = '#047857';
  ctx.fillRect(px + 4, py + 2, tile - 8, 12);
  ctx.fillStyle = '#10B981';
  ctx.fillRect(px + 7, py, tile - 14, 10);
  ctx.fillStyle = '#34D399';
  ctx.fillRect(px + 9, py - 2, 3, 5);
}

function drawMeetingTable(ctx, x, y, w, h, tile) {
  const px = x * tile, py = y * tile;
  // Table surface (light wood)
  ctx.fillStyle = '#E8D5B7';
  ctx.fillRect(px + 3, py + 3, w * tile - 6, h * tile - 6);
  ctx.fillStyle = '#D4B896';
  ctx.fillRect(px + 3, py + h * tile - 6, w * tile - 6, 2);
  ctx.strokeStyle = '#B89968';
  ctx.lineWidth = 1;
  ctx.strokeRect(px + 3, py + 3, w * tile - 6, h * tile - 6);
  // Laptops + papers
  const cx = px + (w * tile) / 2;
  ctx.fillStyle = '#1F2937';
  ctx.fillRect(px + 8, py + 7, 8, 5);
  ctx.fillStyle = THEME.emerald;
  ctx.fillRect(px + 9, py + 8, 6, 3);
  ctx.fillStyle = '#FFFFFF';
  ctx.fillRect(px + w * tile - 16, py + 9, 8, 5);
  // Central element
  ctx.fillStyle = THEME.navy;
  ctx.fillRect(cx - 3, py + (h * tile) / 2 - 2, 6, 4);
  ctx.fillStyle = THEME.emerald;
  ctx.fillRect(cx - 2, py + (h * tile) / 2 - 1, 4, 2);
}

function drawCoffeeMachine(ctx, x, y, tile) {
  const px = x * tile, py = y * tile;
  // Counter
  ctx.fillStyle = '#FFFFFF';
  ctx.fillRect(px + 2, py + 14, tile - 4, tile - 15);
  ctx.fillStyle = '#E2E8F0';
  ctx.fillRect(px + 2, py + 14, tile - 4, 1);
  // Machine body (chrome + navy)
  ctx.fillStyle = '#1E293B';
  ctx.fillRect(px + 4, py + 2, tile - 8, 14);
  ctx.fillStyle = '#334155';
  ctx.fillRect(px + 4, py + 2, tile - 8, 2);
  // Brand strip
  ctx.fillStyle = THEME.emerald;
  ctx.fillRect(px + 6, py + 4, tile - 12, 1);
  // Display
  ctx.fillStyle = THEME.emerald;
  ctx.fillRect(px + 7, py + 6, 3, 2);
  ctx.fillStyle = '#1F2937';
  ctx.fillRect(px + 7, py + 9, tile - 14, 2);
  // Cup area
  ctx.fillStyle = '#CBD5E1';
  ctx.fillRect(px + 7, py + 13, tile - 14, 2);
  // Cup
  ctx.fillStyle = '#FEF3C7';
  ctx.fillRect(px + tile/2 - 2, py + 10, 4, 4);
  ctx.fillStyle = '#78350F';
  ctx.fillRect(px + tile/2 - 1, py + 10, 2, 1);
}

function drawWaterCooler(ctx, x, y, tile) {
  const px = x * tile, py = y * tile;
  // Base (white)
  ctx.fillStyle = '#F8FAFC';
  ctx.fillRect(px + 4, py + 10, tile - 8, tile - 11);
  ctx.fillStyle = '#E2E8F0';
  ctx.fillRect(px + 4, py + 10, tile - 8, 1);
  // Blue tank
  ctx.fillStyle = '#60A5FA';
  ctx.fillRect(px + 5, py + 2, tile - 10, 9);
  ctx.fillStyle = '#93C5FD';
  ctx.fillRect(px + 6, py + 3, tile - 14, 4);
  // Bubbles
  ctx.fillStyle = '#DBEAFE';
  ctx.fillRect(px + 7, py + 5, 1, 1);
  ctx.fillRect(px + 10, py + 7, 1, 1);
  // Tap
  ctx.fillStyle = THEME.emerald;
  ctx.fillRect(px + tile/2 - 1, py + 11, 2, 2);
}

function drawWhiteboard(ctx, x, y, tile) {
  const px = x * tile, py = y * tile;
  // Board (white)
  ctx.fillStyle = '#FFFFFF';
  ctx.fillRect(px + 2, py + 3, tile - 4, tile - 10);
  ctx.strokeStyle = '#94A3B8';
  ctx.lineWidth = 1;
  ctx.strokeRect(px + 2, py + 3, tile - 4, tile - 10);
  // Frame shadow
  ctx.fillStyle = '#475569';
  ctx.fillRect(px + 2, py + tile - 7, tile - 4, 1);
  // Content: chart bars
  ctx.fillStyle = THEME.navy;
  ctx.fillRect(px + 4, py + tile - 11, 1, 4);
  ctx.fillStyle = THEME.emerald;
  ctx.fillRect(px + 6, py + tile - 13, 1, 6);
  ctx.fillStyle = THEME.sky;
  ctx.fillRect(px + 8, py + tile - 10, 1, 3);
  ctx.fillStyle = THEME.navy;
  ctx.fillRect(px + 10, py + tile - 12, 1, 5);
  // Trend line
  ctx.strokeStyle = THEME.emerald;
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(px + 4, py + 7);
  ctx.lineTo(px + 8, py + 6);
  ctx.lineTo(px + tile - 4, py + 5);
  ctx.stroke();
  // Tray + markers
  ctx.fillStyle = '#94A3B8';
  ctx.fillRect(px + 2, py + tile - 7, tile - 4, 2);
  ctx.fillStyle = THEME.navy;
  ctx.fillRect(px + 5, py + tile - 6, 3, 1);
  ctx.fillStyle = THEME.emerald;
  ctx.fillRect(px + 10, py + tile - 6, 3, 1);
  ctx.fillStyle = '#DC2626';
  ctx.fillRect(px + 15, py + tile - 6, 3, 1);
}

function drawSofa(ctx, x, y, tile, color = '#1E40AF') {
  const px = x * tile, py = y * tile;
  // Sofa body
  ctx.fillStyle = color;
  ctx.fillRect(px + 1, py + 7, tile - 2, tile - 9);
  // Cushions
  ctx.fillStyle = 'rgba(255,255,255,0.18)';
  ctx.fillRect(px + 2, py + 8, (tile - 4) / 2 - 1, tile - 13);
  ctx.fillRect(px + tile / 2 + 1, py + 8, (tile - 4) / 2 - 1, tile - 13);
  // Armrests
  ctx.fillStyle = color;
  ctx.fillRect(px + 1, py + 5, 4, tile - 7);
  ctx.fillRect(px + tile - 5, py + 5, 4, tile - 7);
  ctx.fillStyle = 'rgba(0,0,0,0.15)';
  ctx.fillRect(px + 1, py + tile - 3, tile - 2, 2);
  // Pillows
  ctx.fillStyle = THEME.emerald;
  ctx.fillRect(px + 4, py + 8, 3, 3);
}

function drawBookshelf(ctx, x, y, tile) {
  const px = x * tile, py = y * tile;
  // Case
  ctx.fillStyle = '#6B4423';
  ctx.fillRect(px + 1, py + 1, tile - 2, tile - 2);
  ctx.fillStyle = '#8B5A2B';
  ctx.fillRect(px + 1, py + 1, tile - 2, 1);
  // Shelves w/ books
  const shelves = 3;
  for (let i = 0; i < shelves; i++) {
    const sy = py + 3 + i * 6;
    ctx.fillStyle = '#A67B4A';
    ctx.fillRect(px + 2, sy + 5, tile - 4, 1);
    // Books
    const colors = ['#1E40AF', '#10B981', '#DC2626', '#F59E0B', '#8B5CF6', '#0EA5E9'];
    let bx = px + 2;
    while (bx < px + tile - 3) {
      const bw = 1 + Math.floor(Math.abs(Math.sin(bx * (i+1))) * 2) + 1;
      ctx.fillStyle = colors[(bx + i) % colors.length];
      ctx.fillRect(bx, sy, bw, 5);
      bx += bw + 1;
    }
  }
}

function drawPrinter(ctx, x, y, tile) {
  const px = x * tile, py = y * tile;
  // Body
  ctx.fillStyle = '#F8FAFC';
  ctx.fillRect(px + 2, py + 6, tile - 4, tile - 10);
  ctx.fillStyle = '#CBD5E1';
  ctx.fillRect(px + 2, py + 6, tile - 4, 2);
  // Top output
  ctx.fillStyle = '#1F2937';
  ctx.fillRect(px + 4, py + 3, tile - 8, 4);
  ctx.fillStyle = '#FFFFFF';
  ctx.fillRect(px + 5, py + 4, tile - 10, 2);
  // Status LED
  ctx.fillStyle = THEME.emerald;
  ctx.fillRect(px + tile - 5, py + 9, 1, 1);
  // Paper tray
  ctx.fillStyle = '#E2E8F0';
  ctx.fillRect(px + 3, py + tile - 5, tile - 6, 2);
}

function drawFilingCabinet(ctx, x, y, tile) {
  const px = x * tile, py = y * tile;
  ctx.fillStyle = '#94A3B8';
  ctx.fillRect(px + 2, py + 2, tile - 4, tile - 4);
  ctx.fillStyle = '#CBD5E1';
  ctx.fillRect(px + 2, py + 2, tile - 4, 1);
  // 3 drawers
  for (let i = 0; i < 3; i++) {
    const dy = py + 4 + i * 6;
    ctx.fillStyle = '#64748B';
    ctx.fillRect(px + 3, dy + 4, tile - 6, 1);
    // handle
    ctx.fillStyle = '#1E293B';
    ctx.fillRect(px + tile/2 - 2, dy + 1, 4, 1);
  }
}

function drawWindow(ctx, x, y, tile) {
  // Window on wall (narrow strip showing "sky")
  const px = x * tile, py = y * tile;
  const grd = ctx.createLinearGradient(px, py, px + tile, py + tile);
  grd.addColorStop(0, '#BAE6FD');
  grd.addColorStop(1, '#7DD3FC');
  ctx.fillStyle = grd;
  ctx.fillRect(px + 2, py + 2, tile - 4, tile - 4);
  // Frame cross
  ctx.fillStyle = '#E2E8F0';
  ctx.fillRect(px + tile/2 - 1, py + 2, 2, tile - 4);
  ctx.fillRect(px + 2, py + tile/2 - 1, tile - 4, 2);
  // Highlight
  ctx.fillStyle = 'rgba(255,255,255,0.4)';
  ctx.fillRect(px + 3, py + 3, 3, tile - 6);
}

function drawRug(ctx, x, y, w, h, tile, color) {
  const px = x * tile, py = y * tile;
  const pw = w * tile, ph = h * tile;
  ctx.fillStyle = color;
  ctx.fillRect(px + 3, py + 3, pw - 6, ph - 6);
  // Pattern border
  ctx.strokeStyle = 'rgba(255,255,255,0.35)';
  ctx.lineWidth = 1;
  ctx.strokeRect(px + 5, py + 5, pw - 10, ph - 10);
  ctx.strokeStyle = 'rgba(0,0,0,0.15)';
  ctx.strokeRect(px + 3, py + 3, pw - 6, ph - 6);
  // Tassels (corners)
  ctx.fillStyle = 'rgba(255,255,255,0.4)';
  ctx.fillRect(px + 3, py + 3, 2, 2);
  ctx.fillRect(px + pw - 5, py + 3, 2, 2);
  ctx.fillRect(px + 3, py + ph - 5, 2, 2);
  ctx.fillRect(px + pw - 5, py + ph - 5, 2, 2);
}

function drawLamp(ctx, x, y, tile) {
  const px = x * tile, py = y * tile;
  // Stand
  ctx.fillStyle = '#94A3B8';
  ctx.fillRect(px + tile/2 - 1, py + 10, 2, tile - 12);
  ctx.fillStyle = '#64748B';
  ctx.fillRect(px + tile/2 - 4, py + tile - 3, 8, 2);
  // Shade
  ctx.fillStyle = '#FEF3C7';
  ctx.fillRect(px + tile/2 - 5, py + 4, 10, 8);
  ctx.fillStyle = '#FDE68A';
  ctx.fillRect(px + tile/2 - 5, py + 4, 10, 2);
  // Glow
  ctx.fillStyle = 'rgba(253, 224, 71, 0.2)';
  ctx.fillRect(px + tile/2 - 8, py + 12, 16, 4);
}

function drawSink(ctx, x, y, tile) {
  const px = x * tile, py = y * tile;
  // Counter
  ctx.fillStyle = '#FFFFFF';
  ctx.fillRect(px + 1, py + 4, tile - 2, tile - 5);
  ctx.fillStyle = '#E2E8F0';
  ctx.fillRect(px + 1, py + 4, tile - 2, 1);
  // Sink basin
  ctx.fillStyle = '#CBD5E1';
  ctx.fillRect(px + 4, py + 8, tile - 8, 10);
  ctx.fillStyle = '#94A3B8';
  ctx.fillRect(px + 5, py + 9, tile - 10, 8);
  // Faucet
  ctx.fillStyle = '#64748B';
  ctx.fillRect(px + tile/2 - 1, py + 5, 2, 5);
  ctx.fillRect(px + tile/2 - 2, py + 8, 4, 2);
}

function drawFridge(ctx, x, y, tile) {
  const px = x * tile, py = y * tile;
  ctx.fillStyle = '#FFFFFF';
  ctx.fillRect(px + 2, py + 1, tile - 4, tile - 2);
  ctx.fillStyle = '#E2E8F0';
  ctx.fillRect(px + 2, py + 1, tile - 4, 1);
  // Door divide
  ctx.fillStyle = '#CBD5E1';
  ctx.fillRect(px + 2, py + 10, tile - 4, 1);
  // Handles
  ctx.fillStyle = '#64748B';
  ctx.fillRect(px + tile - 5, py + 4, 2, 4);
  ctx.fillRect(px + tile - 5, py + 14, 2, 4);
}

function drawTV(ctx, x, y, tile) {
  const px = x * tile, py = y * tile;
  // Frame
  ctx.fillStyle = '#0F172A';
  ctx.fillRect(px + 1, py + 3, tile - 2, tile - 8);
  // Screen — showing Ascenda dashboard
  ctx.fillStyle = THEME.navy;
  ctx.fillRect(px + 2, py + 4, tile - 4, tile - 10);
  // chart bars
  ctx.fillStyle = THEME.emerald;
  ctx.fillRect(px + 4, py + tile - 8, 2, 2);
  ctx.fillRect(px + 7, py + tile - 10, 2, 4);
  ctx.fillRect(px + 10, py + tile - 9, 2, 3);
  ctx.fillStyle = THEME.emerald;
  ctx.fillRect(px + 4, py + 6, 4, 1);
  ctx.fillStyle = THEME.sky;
  ctx.fillRect(px + 10, py + 6, 4, 1);
  // Stand
  ctx.fillStyle = '#475569';
  ctx.fillRect(px + tile/2 - 3, py + tile - 5, 6, 3);
}

function drawServerRack(ctx, x, y, tile) {
  const px = x * tile, py = y * tile;
  ctx.fillStyle = '#18181B';
  ctx.fillRect(px + 3, py + 1, tile - 6, tile - 2);
  ctx.fillStyle = '#27272A';
  ctx.fillRect(px + 3, py + 1, tile - 6, 1);
  for (let i = 0; i < 4; i++) {
    ctx.fillStyle = i % 2 ? '#27272A' : '#3F3F46';
    ctx.fillRect(px + 5, py + 3 + i * 5, tile - 10, 3);
    ctx.fillStyle = i === 0 ? THEME.emerald : i === 1 ? '#60A5FA' : THEME.emerald;
    ctx.fillRect(px + tile - 7, py + 4 + i * 5, 1, 1);
    ctx.fillRect(px + tile - 9, py + 4 + i * 5, 1, 1);
  }
}

// ————— Main office draw —————
function drawOffice(ctx, state) {
  const { zones, desks, tile, mapW, mapH } = state;

  // Outer floor (hallway + void): light tile
  ctx.fillStyle = THEME.bgSoft;
  ctx.fillRect(0, 0, mapW * tile, mapH * tile);

  // Floors per zone
  zones.forEach(z => drawFloor(ctx, z, tile));

  // Zone borders
  zones.forEach(z => drawZoneWalls(ctx, z, tile));

  // Decorations per zone — RICH
  zones.forEach(z => {
    const d = window.DEPARTMENTS[z.dept];

    if (z.dept === 'executive') {
      // CEO corner: rug + sofas + plants + bookshelf
      drawRug(ctx, z.x + 1, z.y + 4, 5, 3, tile, 'rgba(30, 64, 175, 0.1)');
      drawLargePlant(ctx, z.x + z.w - 2, z.y + 1, tile);
      drawLargePlant(ctx, z.x + 1,       z.y + z.h - 2, tile);
      drawSofa(ctx, z.x + z.w - 3,  z.y + z.h - 2, tile, THEME.navy);
      drawBookshelf(ctx, z.x + z.w - 4, z.y + 1, tile);
      drawWindow(ctx, z.x + 2, z.y, tile);
      drawWindow(ctx, z.x + 5, z.y, tile);
    }
    else if (z.dept === 'meeting') {
      drawMeetingTable(ctx, z.x + 1, z.y + 1, z.w - 2, z.h - 2, tile);
      drawWhiteboard(ctx, z.x + z.w - 2, z.y + 2, tile);
      drawWhiteboard(ctx, z.x + z.w - 2, z.y + 4, tile);
      drawTV(ctx, z.x + 1, z.y + 2, tile);
      drawLargePlant(ctx, z.x + 1, z.y + z.h - 2, tile);
    }
    else if (z.dept === 'marketing') {
      drawLargePlant(ctx, z.x + z.w - 2, z.y + z.h - 2, tile);
      drawWhiteboard(ctx, z.x + 1, z.y + z.h - 2, tile);
      drawWhiteboard(ctx, z.x + 3, z.y + z.h - 2, tile);
      drawTV(ctx, z.x + z.w - 2, z.y + 1, tile);
      drawWindow(ctx, z.x + z.w - 3, z.y, tile);
      drawPlant(ctx, z.x + 1, z.y + 1, tile, 0);
    }
    else if (z.dept === 'finance') {
      drawServerRack(ctx, z.x + z.w - 2, z.y + z.h - 2, tile);
      drawServerRack(ctx, z.x + z.w - 3, z.y + z.h - 2, tile);
      drawLargePlant(ctx, z.x + 1, z.y + z.h - 2, tile);
      drawTV(ctx, z.x + z.w - 2, z.y + 1, tile);
      drawFilingCabinet(ctx, z.x + 1, z.y + 1, tile);
      drawWindow(ctx, z.x + 4, z.y, tile);
    }
    else if (z.dept === 'cafe') {
      // Cafeteria: coffee bar + lounge
      drawCoffeeMachine(ctx, z.x + 1, z.y + 1, tile);
      drawCoffeeMachine(ctx, z.x + 2, z.y + 1, tile);
      drawSink(ctx, z.x + 3, z.y + 1, tile);
      drawFridge(ctx, z.x + 4, z.y + 1, tile);
      drawSofa(ctx, z.x + 1, z.y + z.h - 2, tile, '#F59E0B');
      drawSofa(ctx, z.x + 5, z.y + z.h - 2, tile, THEME.emerald);
      drawMeetingTable(ctx, z.x + 3, z.y + 2, 3, 2, tile);
      drawLargePlant(ctx, z.x + z.w - 2, z.y + 1, tile);
      drawLargePlant(ctx, z.x + z.w - 2, z.y + z.h - 2, tile);
      drawWindow(ctx, z.x + 6, z.y, tile);
    }
    else if (z.dept === 'hr') {
      drawPlant(ctx, z.x + z.w - 2, z.y + z.h - 2, tile, 1);
      drawSofa(ctx, z.x + 1, z.y + z.h - 2, tile, THEME.sky);
      drawBookshelf(ctx, z.x + z.w - 2, z.y + 1, tile);
      drawLamp(ctx, z.x + 1, z.y + 1, tile);
    }
    else if (z.dept === 'research') {
      drawWhiteboard(ctx, z.x + z.w - 2, z.y + 1, tile);
      drawWhiteboard(ctx, z.x + z.w - 2, z.y + z.h - 2, tile);
      drawBookshelf(ctx, z.x + 1, z.y + z.h - 2, tile);
      drawLargePlant(ctx, z.x + z.w - 3, z.y + z.h - 2, tile);
    }
    else if (z.dept === 'scheduler') {
      drawWhiteboard(ctx, z.x + 1, z.y + z.h - 2, tile);
      drawTV(ctx, z.x + z.w - 2, z.y + 1, tile);
      drawPlant(ctx, z.x + z.w - 2, z.y + z.h - 2, tile, 1);
    }
    else if (z.dept === 'legal') {
      drawBookshelf(ctx, z.x + 1, z.y + 1, tile);
      drawBookshelf(ctx, z.x + 1, z.y + z.h - 2, tile);
      drawBookshelf(ctx, z.x + z.w - 2, z.y + 1, tile);
      drawLamp(ctx, z.x + z.w - 2, z.y + z.h - 2, tile);
      drawFilingCabinet(ctx, z.x + 2, z.y + 1, tile);
    }
    else if (z.dept === 'accounting') {
      drawFilingCabinet(ctx, z.x + 1, z.y + 1, tile);
      drawFilingCabinet(ctx, z.x + 2, z.y + 1, tile);
      drawPrinter(ctx, z.x + z.w - 2, z.y + 1, tile);
      drawPlant(ctx, z.x + z.w - 2, z.y + z.h - 2, tile, 0);
    }
    else if (z.dept === 'callcenter') {
      drawWaterCooler(ctx, z.x + z.w - 1, z.y + z.h - 2, tile);
      drawTV(ctx, z.x + 1, z.y + 1, tile);
      drawPlant(ctx, z.x + 1, z.y + z.h - 2, tile, 1);
      drawWindow(ctx, z.x + 6, z.y, tile);
    }
    else if (z.dept === 'sales') {
      drawTV(ctx, z.x + z.w - 2, z.y + 1, tile);
      drawLargePlant(ctx, z.x + 1, z.y + z.h - 2, tile);
      drawWhiteboard(ctx, z.x + z.w - 2, z.y + z.h - 2, tile);
    }
  });

  // Hallway decoration (central strip)
  drawPlant(ctx, 11, 10, tile, 0);
  drawPlant(ctx, 22, 10, tile, 1);
  drawPlant(ctx, 33, 10, tile, 0);
  drawPlant(ctx, 11, 9, tile, 1);
  drawPlant(ctx, 22, 9, tile, 0);
  // Seating in hallway
  // drawSofa(ctx, 5, 10, tile, '#CBD5E1');

  // Desks + chairs on top
  desks.forEach(d => {
    drawDesk(ctx, d, tile);
    const chairColor = window.DEPARTMENTS[
      window.AGENTS.find(a => a.home === d.id)?.dept
    ]?.color || THEME.navy;
    drawChair(ctx, d.x, d.y, d.facing, tile, chairColor);
  });

  // Zone labels (glass pills)
  state.zones.forEach(z => {
    const d = window.DEPARTMENTS[z.dept];
    if (!d) return;
    const label = z.name.toUpperCase();
    ctx.font = 'bold 9px "JetBrains Mono", monospace';
    ctx.textAlign = 'left';
    const w = ctx.measureText(label).width + 18;
    const lx = z.x * tile + 4;
    const ly = z.y * tile + 4;
    // Pill bg
    ctx.fillStyle = 'rgba(255, 255, 255, 0.9)';
    roundRect(ctx, lx, ly, w, 14, 4);
    ctx.fill();
    ctx.strokeStyle = d.color + '40';
    ctx.lineWidth = 1;
    roundRect(ctx, lx + 0.5, ly + 0.5, w, 14, 4);
    ctx.stroke();
    // Icon
    ctx.fillStyle = d.color;
    ctx.font = 'bold 10px system-ui';
    ctx.fillText(d.icon, lx + 4, ly + 11);
    // Text
    ctx.fillStyle = THEME.ink;
    ctx.font = 'bold 9px "JetBrains Mono", monospace';
    ctx.fillText(label, lx + 14, ly + 10);
  });
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y,     x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x,     y + h, r);
  ctx.arcTo(x,     y + h, x,     y,     r);
  ctx.arcTo(x,     y,     x + w, y,     r);
  ctx.closePath();
}

// ————— Agent sprite — more detailed, Ascenda-style —————
function drawAgent(ctx, a, tile, now) {
  const px = a.px, py = a.py;
  const deptColor = window.DEPARTMENTS[a.dept]?.color || '#64748B';
  const bob = a.walking ? Math.sin(now / 120 + a.id.charCodeAt(1)) * 1 : 0;

  // Shadow (soft elliptical)
  ctx.fillStyle = 'rgba(15, 23, 42, 0.18)';
  ctx.beginPath();
  ctx.ellipse(px, py + tile * 0.9, 7, 2.5, 0, 0, Math.PI * 2);
  ctx.fill();

  // Legs
  const legOffset = a.walking ? Math.sin(now / 100) * 1.5 : 0;
  ctx.fillStyle = '#1E293B';
  ctx.fillRect(px - 3, py + 16 + bob, 2, 5 - legOffset);
  ctx.fillRect(px + 1, py + 16 + bob, 2, 5 + legOffset);
  // Shoes
  ctx.fillStyle = '#0F172A';
  ctx.fillRect(px - 3, py + 20 + bob - legOffset, 3, 1);
  ctx.fillRect(px + 1, py + 20 + bob + legOffset, 3, 1);

  // Body (shirt)
  ctx.fillStyle = a.shirt || deptColor;
  ctx.fillRect(px - 4, py + 9 + bob, 8, 8);
  // Shirt highlight
  ctx.fillStyle = 'rgba(255,255,255,0.2)';
  ctx.fillRect(px - 4, py + 9 + bob, 8, 1);
  ctx.fillStyle = 'rgba(0,0,0,0.18)';
  ctx.fillRect(px - 4, py + 15 + bob, 8, 2);
  // Collar / tie
  ctx.fillStyle = '#FFFFFF';
  ctx.fillRect(px - 1, py + 9 + bob, 2, 2);
  ctx.fillStyle = deptColor;
  ctx.fillRect(px, py + 11 + bob, 1, 3);

  // Head
  ctx.fillStyle = a.skin || '#F1C27D';
  ctx.fillRect(px - 3, py + 3 + bob, 6, 7);
  // Hair
  ctx.fillStyle = a.hair || '#1F1F1F';
  ctx.fillRect(px - 3, py + 3 + bob, 6, 3);
  ctx.fillRect(px - 3, py + 3 + bob, 2, 5);
  ctx.fillRect(px + 1, py + 3 + bob, 2, 5);
  // Eyes
  ctx.fillStyle = '#0F172A';
  ctx.fillRect(px - 2, py + 7 + bob, 1, 1);
  ctx.fillRect(px + 1, py + 7 + bob, 1, 1);

  // Status indicator orb (above head)
  const orbY = py + 1 + bob;
  if (a.status === 'meeting') {
    ctx.fillStyle = '#F59E0B';
    ctx.beginPath(); ctx.arc(px + 4, orbY, 2, 0, Math.PI * 2); ctx.fill();
  } else if (a.status === 'blocked') {
    const pulse = 0.5 + 0.5 * Math.sin(now / 200);
    ctx.fillStyle = `rgba(239, 68, 68, ${0.7 + pulse * 0.3})`;
    ctx.beginPath(); ctx.arc(px + 4, orbY, 2.5, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = `rgba(239, 68, 68, ${pulse * 0.6})`;
    ctx.beginPath(); ctx.arc(px + 4, orbY, 4, 0, Math.PI * 2); ctx.stroke();
  } else if (a.status === 'paused') {
    ctx.fillStyle = '#94A3B8';
    ctx.beginPath(); ctx.arc(px + 4, orbY, 2, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(px + 3, orbY - 1, 1, 2);
    ctx.fillRect(px + 5, orbY - 1, 1, 2);
  } else if (a.status === 'working') {
    const pulse = 0.5 + 0.5 * Math.sin(now / 300);
    ctx.fillStyle = `rgba(16, 185, 129, ${0.6 + pulse * 0.4})`;
    ctx.beginPath(); ctx.arc(px + 4, orbY, 2, 0, Math.PI * 2); ctx.fill();
  } else if (a.status === 'traveling') {
    ctx.fillStyle = '#0EA5E9';
    ctx.beginPath(); ctx.arc(px + 4, orbY, 2, 0, Math.PI * 2); ctx.fill();
  }

  // Selection ring (emerald)
  if (a.selected) {
    const pulse = 0.4 + 0.3 * Math.sin(now / 200);
    ctx.strokeStyle = THEME.emerald;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.ellipse(px, py + tile * 0.85, 10, 4, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.strokeStyle = `rgba(16, 185, 129, ${pulse})`;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.ellipse(px, py + tile * 0.85, 13 + pulse * 2, 5 + pulse, 0, 0, Math.PI * 2);
    ctx.stroke();
  }
  if (a.hovered && !a.selected) {
    ctx.strokeStyle = 'rgba(30, 64, 175, 0.5)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.ellipse(px, py + tile * 0.85, 10, 4, 0, 0, Math.PI * 2);
    ctx.stroke();
  }
}

// ————— Bubbles (light glass) —————
function drawBubble(ctx, a, tile, now) {
  if (!a.bubble) return;
  const text = a.bubble.text;
  const isThought = a.bubble.type === 'thought';
  ctx.font = '10px "JetBrains Mono", system-ui';
  const metrics = ctx.measureText(text);
  const tw = Math.min(metrics.width, 180);
  const bw = tw + 14;
  const bh = 20;
  const bx = a.px - bw / 2;
  const by = a.py - 22;

  // Shadow
  ctx.fillStyle = 'rgba(15, 23, 42, 0.12)';
  roundRect(ctx, bx + 1, by + 2, bw, bh, 6);
  ctx.fill();

  // Bubble bg (glass)
  ctx.fillStyle = isThought ? 'rgba(255, 255, 255, 0.96)' : 'rgba(30, 64, 175, 0.95)';
  roundRect(ctx, bx, by, bw, bh, 6);
  ctx.fill();
  ctx.strokeStyle = isThought ? 'rgba(203, 213, 225, 0.8)' : 'rgba(16, 185, 129, 0.6)';
  ctx.lineWidth = 1;
  ctx.stroke();

  // Tail
  if (isThought) {
    ctx.fillStyle = 'rgba(255, 255, 255, 0.96)';
    ctx.beginPath(); ctx.arc(a.px - 2, by + bh + 3, 2, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = 'rgba(203, 213, 225, 0.8)'; ctx.stroke();
    ctx.beginPath(); ctx.arc(a.px + 1, by + bh + 7, 1.5, 0, Math.PI * 2); ctx.fill();
    ctx.stroke();
  } else {
    ctx.fillStyle = 'rgba(30, 64, 175, 0.95)';
    ctx.beginPath();
    ctx.moveTo(a.px - 3, by + bh);
    ctx.lineTo(a.px, by + bh + 4);
    ctx.lineTo(a.px + 3, by + bh);
    ctx.closePath();
    ctx.fill();
  }

  // Text
  let display = text;
  if (metrics.width > 180) {
    while (ctx.measureText(display + '…').width > 175 && display.length > 3) display = display.slice(0, -1);
    display += '…';
  }
  ctx.fillStyle = isThought ? THEME.ink : '#FFFFFF';
  ctx.textAlign = 'left';
  ctx.fillText(display, bx + 7, by + 13);
}

// ————— Connections —————
function drawConnection(ctx, a, b, now) {
  ctx.strokeStyle = 'rgba(16, 185, 129, 0.6)';
  ctx.lineWidth = 1.5;
  ctx.setLineDash([4, 3]);
  ctx.lineDashOffset = -now / 40;
  ctx.beginPath();
  ctx.moveTo(a.px, a.py);
  ctx.lineTo(b.px, b.py);
  ctx.stroke();
  ctx.setLineDash([]);
  // Packet
  const t = ((now / 1000) % 1);
  const px = a.px + (b.px - a.px) * t;
  const py = a.py + (b.py - a.py) * t;
  ctx.fillStyle = THEME.emerald;
  ctx.beginPath(); ctx.arc(px, py, 3, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = 'rgba(16, 185, 129, 0.3)';
  ctx.beginPath(); ctx.arc(px, py, 5, 0, Math.PI * 2); ctx.fill();
}

// ————— Heatmap —————
function drawHeatmap(ctx, agents, tile, mapW, mapH) {
  const res = 4;
  const cellW = Math.ceil((mapW * tile) / res);
  const cellH = Math.ceil((mapH * tile) / res);
  const grid = new Float32Array(cellW * cellH);
  agents.forEach(a => {
    if (a.status !== 'working' && a.status !== 'meeting') return;
    const cx = Math.floor(a.px / res);
    const cy = Math.floor(a.py / res);
    const radius = 14;
    for (let dy = -radius; dy <= radius; dy++) {
      for (let dx = -radius; dx <= radius; dx++) {
        const x = cx + dx, y = cy + dy;
        if (x < 0 || y < 0 || x >= cellW || y >= cellH) continue;
        const d = Math.sqrt(dx * dx + dy * dy);
        if (d > radius) continue;
        grid[y * cellW + x] += 1 - d / radius;
      }
    }
  });
  const img = ctx.createImageData(cellW, cellH);
  for (let i = 0; i < grid.length; i++) {
    const v = Math.min(1, grid[i] / 3);
    if (v < 0.05) continue;
    const r = v < 0.5 ? Math.floor(16 + v * 2 * (245 - 16))   : Math.floor(245 - (v - 0.5) * 2 * (245 - 239));
    const g = v < 0.5 ? Math.floor(185 + v * 2 * (158 - 185)) : Math.floor(158 - (v - 0.5) * 2 * (158 - 68));
    const b = v < 0.5 ? Math.floor(129 - v * 2 * (129 - 11))  : Math.floor(11  + (v - 0.5) * 2 * (68 - 11));
    const idx = i * 4;
    img.data[idx] = r; img.data[idx + 1] = g; img.data[idx + 2] = b;
    img.data[idx + 3] = Math.floor(v * 180);
  }
  const tmp = document.createElement('canvas');
  tmp.width = cellW; tmp.height = cellH;
  tmp.getContext('2d').putImageData(img, 0, 0);
  ctx.save();
  ctx.globalCompositeOperation = 'multiply';
  ctx.drawImage(tmp, 0, 0, cellW * res, cellH * res);
  ctx.restore();
}

function drawHoloOverlay(ctx, w, h, now) {
  ctx.save();
  ctx.globalCompositeOperation = 'overlay';
  for (let y = 0; y < h; y += 3) {
    ctx.fillStyle = 'rgba(30, 64, 175, 0.04)';
    ctx.fillRect(0, y, w, 1);
  }
  ctx.globalCompositeOperation = 'source-over';
  const pulse = 0.015 + 0.01 * Math.sin(now / 700);
  ctx.fillStyle = `rgba(16, 185, 129, ${pulse})`;
  ctx.fillRect(0, 0, w, h);
  ctx.restore();
}

// Focus overlay: dim everything EXCEPT the focused zone
function drawFocusMask(ctx, zone, tile, mapW, mapH) {
  if (!zone) return;
  const px = zone.x * tile, py = zone.y * tile;
  const pw = zone.w * tile, ph = zone.h * tile;
  // Dark overlay with cutout for zone
  ctx.save();
  ctx.fillStyle = 'rgba(15, 23, 42, 0.45)';
  // Four rects around the zone
  ctx.fillRect(0, 0, mapW * tile, py - 2);                           // top
  ctx.fillRect(0, py + ph + 2, mapW * tile, mapH * tile - (py + ph + 2)); // bottom
  ctx.fillRect(0, py - 2, px - 2, ph + 4);                           // left
  ctx.fillRect(px + pw + 2, py - 2, mapW * tile - (px + pw + 2), ph + 4); // right
  // Highlight border around zone
  ctx.strokeStyle = THEME.emerald;
  ctx.lineWidth = 3;
  ctx.setLineDash([6, 4]);
  ctx.lineDashOffset = -performance.now() / 50;
  ctx.strokeRect(px - 2, py - 2, pw + 4, ph + 4);
  ctx.setLineDash([]);
  ctx.restore();
}

// ————— Main component —————
function OfficePixel({
  agents, selectedId, onSelectAgent, onHoverAgent, mode, viewport, setViewport,
  connections, tileSize, onZoneClick, focusedZoneId,
}) {
  const canvasRef = useOfRef(null);
  const rafRef = useOfRef(null);
  const lastHoverRef = useOfRef(null);
  const lastZoneHoverRef = useOfRef(null);
  const [dragging, setDragging] = useOfState(null);
  const mouseRef = useOfRef({ x: 0, y: 0, down: false, hasDragged: false });

  const { ZONES, DESKS, MAP_W, MAP_H } = window;
  const tile = tileSize || window.TILE;
  const focusedZone = focusedZoneId ? ZONES.find(z => z.id === focusedZoneId) : null;

  // Resize canvas
  useOfEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const resize = () => {
      const parent = canvas.parentElement;
      const rect = parent.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      canvas.width = rect.width * dpr;
      canvas.height = rect.height * dpr;
      canvas.style.width = rect.width + 'px';
      canvas.style.height = rect.height + 'px';
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas.parentElement);
    return () => ro.disconnect();
  }, []);

  // Render loop
  useOfEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    let running = true;
    const render = (now) => {
      if (!running) return;
      const dpr = window.devicePixelRatio || 1;
      const w = canvas.width, h = canvas.height;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      // Light background: subtle gradient from Ascenda bgSoft → white
      const grd = ctx.createLinearGradient(0, 0, 0, h);
      grd.addColorStop(0, '#EEF2FA');
      grd.addColorStop(1, '#F8FAFC');
      ctx.fillStyle = grd;
      ctx.fillRect(0, 0, w, h);

      // Apply transform
      ctx.setTransform(dpr * viewport.zoom, 0, 0, dpr * viewport.zoom, dpr * viewport.x, dpr * viewport.y);

      // Office
      drawOffice(ctx, { zones: ZONES, desks: DESKS, tile, mapW: MAP_W, mapH: MAP_H });

      if (mode === 'holo') {
        ctx.globalCompositeOperation = 'overlay';
        ctx.fillStyle = 'rgba(30, 64, 175, 0.2)';
        ctx.fillRect(0, 0, MAP_W * tile, MAP_H * tile);
        ctx.globalCompositeOperation = 'source-over';
      }
      if (mode === 'heatmap') drawHeatmap(ctx, agents, tile, MAP_W, MAP_H);

      connections.forEach(([idA, idB]) => {
        const a = agents.find(x => x.id === idA);
        const b = agents.find(x => x.id === idB);
        if (a && b) drawConnection(ctx, a, b, now);
      });

      agents.forEach(a => drawAgent(ctx, a, tile, now));
      agents.forEach(a => drawBubble(ctx, a, tile, now));

      // Focus mask on top (before holo overlay)
      if (focusedZone) drawFocusMask(ctx, focusedZone, tile, MAP_W, MAP_H);

      ctx.setTransform(1, 0, 0, 1, 0, 0);
      if (mode === 'holo') drawHoloOverlay(ctx, w, h, now);

      rafRef.current = requestAnimationFrame(render);
    };
    rafRef.current = requestAnimationFrame(render);
    return () => { running = false; cancelAnimationFrame(rafRef.current); };
  }, [agents, mode, viewport, connections, tile, focusedZoneId]);

  const getWorldPos = useOfCallback((sx, sy) => {
    const rect = canvasRef.current.getBoundingClientRect();
    return {
      x: (sx - rect.left - viewport.x) / viewport.zoom,
      y: (sy - rect.top  - viewport.y) / viewport.zoom,
    };
  }, [viewport]);

  const pickAgent = useOfCallback((sx, sy) => {
    const { x: wx, y: wy } = getWorldPos(sx, sy);
    let best = null, bestD = 14;
    for (const a of agents) {
      const d = Math.hypot(a.px - wx, a.py - wy - tile * 0.4);
      if (d < bestD) { bestD = d; best = a; }
    }
    return best;
  }, [agents, getWorldPos, tile]);

  const pickZone = useOfCallback((sx, sy) => {
    const { x: wx, y: wy } = getWorldPos(sx, sy);
    const tx = wx / tile, ty = wy / tile;
    for (const z of ZONES) {
      if (tx >= z.x && tx < z.x + z.w && ty >= z.y && ty < z.y + z.h) {
        if (z.dept === 'hall') continue;
        return z;
      }
    }
    return null;
  }, [getWorldPos, tile, ZONES]);

  const onPointerDown = (e) => {
    mouseRef.current = { x: e.clientX, y: e.clientY, down: true, hasDragged: false };
    setDragging({ startX: e.clientX, startY: e.clientY, vx: viewport.x, vy: viewport.y });
  };
  const onPointerMove = (e) => {
    if (mouseRef.current.down) {
      const dx = e.clientX - mouseRef.current.x;
      const dy = e.clientY - mouseRef.current.y;
      if (Math.abs(dx) > 3 || Math.abs(dy) > 3) mouseRef.current.hasDragged = true;
      if (dragging) {
        setViewport(v => ({ ...v, x: dragging.vx + (e.clientX - dragging.startX), y: dragging.vy + (e.clientY - dragging.startY) }));
      }
    } else {
      const picked = pickAgent(e.clientX, e.clientY);
      if (picked?.id !== lastHoverRef.current) {
        lastHoverRef.current = picked?.id || null;
        onHoverAgent && onHoverAgent(picked?.id || null);
      }
    }
  };
  const onPointerUp = (e) => {
    if (!mouseRef.current.hasDragged) {
      const pickedAgent = pickAgent(e.clientX, e.clientY);
      if (pickedAgent) {
        onSelectAgent(pickedAgent.id);
      } else {
        // No agent — maybe zone
        const zone = pickZone(e.clientX, e.clientY);
        if (zone && onZoneClick) {
          onZoneClick(zone.id);
        } else {
          onSelectAgent(null);
        }
      }
    }
    mouseRef.current.down = false;
    setDragging(null);
  };
  const onWheel = (e) => {
    e.preventDefault();
    const delta = -e.deltaY * 0.001;
    setViewport(v => {
      const newZoom = Math.max(0.4, Math.min(3, v.zoom + delta * v.zoom));
      const rect = canvasRef.current.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;
      const scale = newZoom / v.zoom;
      return { zoom: newZoom, x: mx - (mx - v.x) * scale, y: my - (my - v.y) * scale };
    });
  };

  return (
    <canvas
      ref={canvasRef}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerLeave={() => { mouseRef.current.down = false; setDragging(null); }}
      onWheel={onWheel}
      style={{
        width: '100%', height: '100%',
        cursor: dragging ? 'grabbing' : lastHoverRef.current ? 'pointer' : 'grab',
        imageRendering: 'pixelated',
        display: 'block',
        touchAction: 'none',
      }}
    />
  );
}

window.OfficePixel = OfficePixel;
window.OFFICE_THEME = THEME;
