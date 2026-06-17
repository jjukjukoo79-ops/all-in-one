# Build white-bg static icon (.ico/.png) and a "walking" animated GIF from a source character PNG.
# ASCII-only comments (PS 5.1 encoding safety).
Add-Type -AssemblyName System.Drawing

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $dir) { $dir = "C:\Users\icecake\all-in-one" }
$src = Join-Path $dir 'mascot-src.png'   # working copy of the source image

# ---- C# helper: background-key to transparent + crop, and animated GIF writer ----
$cs = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;

public class Mascot {
  // Load image, make background transparent (flood from corners by color, or use existing alpha), crop to content.
  public static Bitmap MakeTransparent(string path, int tol) {
    Bitmap src = new Bitmap(path);
    int W = src.Width, H = src.Height;
    Bitmap bmp = new Bitmap(W, H, PixelFormat.Format32bppArgb);
    using (Graphics g = Graphics.FromImage(bmp)) { g.Clear(Color.Transparent); g.DrawImage(src, 0, 0, W, H); }
    src.Dispose();

    BitmapData d = bmp.LockBits(new Rectangle(0,0,W,H), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    int stride = d.Stride; int total = Math.Abs(stride) * H;
    byte[] buf = new byte[total];
    Marshal.Copy(d.Scan0, buf, 0, total);

    // corner sample
    int c0 = 0; // (0,0)
    byte bA = buf[c0+3], bR = buf[c0+2], bG = buf[c0+1], bB = buf[c0+0];

    bool[] vis = new bool[W*H];
    Stack<int> st = new Stack<int>();
    int[] seeds = { 0, (W-1), (H-1)*W, (H-1)*W + (W-1) };
    foreach (int s in seeds) st.Push(s);

    bool srcHasAlpha = (bA < 128);
    while (st.Count > 0) {
      int pidx = st.Pop();
      if (pidx < 0 || pidx >= W*H) continue;
      if (vis[pidx]) continue;
      vis[pidx] = true;
      int x = pidx % W, y = pidx / W;
      int i = y*stride + x*4;
      bool isBg;
      if (srcHasAlpha) { isBg = buf[i+3] < 40; }
      else {
        int diff = Math.Abs(buf[i+2]-bR) + Math.Abs(buf[i+1]-bG) + Math.Abs(buf[i+0]-bB);
        isBg = diff <= tol;
      }
      if (!isBg) continue;       // boundary (character outline) stops the flood
      buf[i+3] = 0;              // make transparent
      if (x > 0)   st.Push(pidx-1);
      if (x < W-1) st.Push(pidx+1);
      if (y > 0)   st.Push(pidx-W);
      if (y < H-1) st.Push(pidx+W);
    }

    // bounding box of non-transparent
    int minX=W, minY=H, maxX=-1, maxY=-1;
    for (int y=0;y<H;y++){ int row=y*stride; for(int x=0;x<W;x++){ if(buf[row+x*4+3] > 16){ if(x<minX)minX=x; if(x>maxX)maxX=x; if(y<minY)minY=y; if(y>maxY)maxY=y; } } }
    Marshal.Copy(buf, 0, d.Scan0, total);
    bmp.UnlockBits(d);
    if (maxX < 0) return bmp; // nothing found
    int pad = 6;
    minX = Math.Max(0, minX-pad); minY = Math.Max(0, minY-pad);
    maxX = Math.Min(W-1, maxX+pad); maxY = Math.Min(H-1, maxY+pad);
    Rectangle crop = new Rectangle(minX, minY, maxX-minX+1, maxY-minY+1);
    Bitmap outb = new Bitmap(crop.Width, crop.Height, PixelFormat.Format32bppArgb);
    using (Graphics g2 = Graphics.FromImage(outb)) g2.DrawImage(bmp, new Rectangle(0,0,crop.Width,crop.Height), crop, GraphicsUnit.Pixel);
    bmp.Dispose();
    return outb;
  }

  // Extract palette + LZW image data from a single-frame GIF produced by System.Drawing.
  private static void ParseGif(byte[] gif, out byte[] lct, out int lctEntries, out byte minCode, out byte[] imgData) {
    int p = 6;                       // skip "GIF89a"
    p += 4;                          // skip logical screen w,h
    byte packed = gif[p]; p += 1;
    p += 2;                          // bgcolor + aspect
    lct = null; lctEntries = 0;
    if ((packed & 0x80) != 0) { lctEntries = 2 << (packed & 7); lct = new byte[lctEntries*3]; Array.Copy(gif, p, lct, 0, lctEntries*3); p += lctEntries*3; }
    while (true) {
      byte b = gif[p];
      if (b == 0x21) { p += 2; while (gif[p] != 0) { p += gif[p] + 1; } p += 1; }
      else if (b == 0x2C) { break; }
      else { break; }
    }
    byte imgPacked = gif[p+9];
    p += 10;
    if ((imgPacked & 0x80) != 0) { int n = 2 << (imgPacked & 7); lct = new byte[n*3]; lctEntries = n; Array.Copy(gif, p, lct, 0, n*3); p += n*3; }
    minCode = gif[p]; p += 1;
    int dataStart = p;
    while (gif[p] != 0) { p += gif[p] + 1; }
    int dataEndIncl = p; // include terminator 0x00
    int len = dataEndIncl - dataStart + 1;
    imgData = new byte[len];
    Array.Copy(gif, dataStart, imgData, 0, len);
  }

  public static void SaveAniGif(string outPath, Bitmap[] frames, int delayCs, int loop) {
    using (FileStream fs = new FileStream(outPath, FileMode.Create))
    using (BinaryWriter w = new BinaryWriter(fs)) {
      int cw = frames[0].Width, ch = frames[0].Height;
      // Header + Logical Screen Descriptor (no global color table)
      w.Write(new byte[]{0x47,0x49,0x46,0x38,0x39,0x61}); // GIF89a
      w.Write((byte)(cw & 0xFF)); w.Write((byte)((cw>>8)&0xFF));
      w.Write((byte)(ch & 0xFF)); w.Write((byte)((ch>>8)&0xFF));
      w.Write((byte)0x70); // packed: no GCT, color res
      w.Write((byte)0);    // bg color index
      w.Write((byte)0);    // aspect
      // NETSCAPE looping extension
      w.Write(new byte[]{0x21,0xFF,0x0B});
      w.Write(System.Text.Encoding.ASCII.GetBytes("NETSCAPE2.0"));
      w.Write(new byte[]{0x03,0x01});
      w.Write((byte)(loop & 0xFF)); w.Write((byte)((loop>>8)&0xFF));
      w.Write((byte)0x00);

      foreach (Bitmap fr in frames) {
        byte[] gifBytes;
        using (MemoryStream ms = new MemoryStream()) { fr.Save(ms, ImageFormat.Gif); gifBytes = ms.ToArray(); }
        byte[] lct; int lctEntries; byte minCode; byte[] imgData;
        ParseGif(gifBytes, out lct, out lctEntries, out minCode, out imgData);
        int sizeBits = 0; int n = lctEntries; while (n > 2) { n >>= 1; sizeBits++; } // log2(entries)-1
        // Graphic Control Extension (delay + disposal)
        w.Write(new byte[]{0x21,0xF9,0x04,0x04});
        w.Write((byte)(delayCs & 0xFF)); w.Write((byte)((delayCs>>8)&0xFF));
        w.Write((byte)0x00); w.Write((byte)0x00);
        // Image Descriptor with Local Color Table
        w.Write((byte)0x2C);
        w.Write((byte)0); w.Write((byte)0); // left
        w.Write((byte)0); w.Write((byte)0); // top
        w.Write((byte)(cw & 0xFF)); w.Write((byte)((cw>>8)&0xFF));
        w.Write((byte)(ch & 0xFF)); w.Write((byte)((ch>>8)&0xFF));
        w.Write((byte)(0x80 | (sizeBits & 0x07))); // LCT present
        w.Write(lct, 0, lctEntries*3);
        w.Write(minCode);
        w.Write(imgData); // sub-blocks + 0x00 terminator
      }
      w.Write((byte)0x3B); // trailer
    }
  }
}
"@
Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

# ---- 1) Make transparent + cropped master ----
$master = [Mascot]::MakeTransparent($src, 70)
Write-Host ("master size: {0}x{1}" -f $master.Width, $master.Height)
$master.Save((Join-Path $dir 'mascot-trans.png'), [System.Drawing.Imaging.ImageFormat]::Png)  # transparent for dashboard

# helper: draw master centered onto a white square at given size
function New-WhiteIcon([int]$S, [double]$fill){
  $bmp = New-Object System.Drawing.Bitmap($S,$S)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode='AntiAlias'; $g.InterpolationMode='HighQualityBicubic'
  $g.Clear([System.Drawing.Color]::White)
  $target = $S * $fill
  $scale = [Math]::Min($target/$master.Width, $target/$master.Height)
  $dw = $master.Width*$scale; $dh = $master.Height*$scale
  $g.DrawImage($master, ($S-$dw)/2, ($S-$dh)/2, $dw, $dh)
  $g.Dispose()
  return $bmp
}

# ---- 2) Static white PNG + ICO ----
$png = New-WhiteIcon 256 0.86
$png.Save((Join-Path $dir 'mascot-white.png'), [System.Drawing.Imaging.ImageFormat]::Png)

$sizes = @(256,64,48,32,16)
$pngList = @()
foreach($s in $sizes){
  $b = New-WhiteIcon $s 0.88
  $ms = New-Object System.IO.MemoryStream
  $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $pngList += ,($ms.ToArray()); $b.Dispose(); $ms.Dispose()
}
$icoPath = Join-Path $dir 'mascot.ico'
$fs = New-Object System.IO.FileStream($icoPath, [System.IO.FileMode]::Create)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$sizes.Count)
$offset = 6 + (16*$sizes.Count)
for($i=0;$i -lt $sizes.Count;$i++){
  $s=$sizes[$i]; $len=$pngList[$i].Length
  if($s -ge 256){$dim=0}else{$dim=$s}
  $bw.Write([Byte]$dim); $bw.Write([Byte]$dim); $bw.Write([Byte]0); $bw.Write([Byte]0)
  $bw.Write([UInt16]1); $bw.Write([UInt16]32); $bw.Write([UInt32]$len); $bw.Write([UInt32]$offset)
  $offset += $len
}
foreach($pp in $pngList){ $bw.Write($pp) }
$bw.Flush(); $bw.Close(); $fs.Close()
Write-Host "ICON created: $icoPath"

# ---- 3) Walking animated GIF ----
$canvas = 240
$N = 12
$frames = New-Object System.Collections.Generic.List[System.Drawing.Bitmap]
for($k=0;$k -lt $N;$k++){
  $t = $k / [double]$N
  $phase = 2*[Math]::PI*$t
  $angle = 5.0*[Math]::Sin($phase)               # gentle sway (lean)
  $bob   = -8.0*[Math]::Abs([Math]::Sin($phase*2)) # two footfall hops per loop
  $xsway = 4.0*[Math]::Sin($phase)               # slight left-right drift
  $bmp = New-Object System.Drawing.Bitmap($canvas,$canvas)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode='AntiAlias'; $g.InterpolationMode='HighQualityBicubic'
  $g.Clear([System.Drawing.Color]::White)
  $target = $canvas*0.80
  $scale = [Math]::Min($target/$master.Width, $target/$master.Height)
  $dw = $master.Width*$scale; $dh = $master.Height*$scale
  $st = $g.Save()
  $g.TranslateTransform([single]($canvas/2 + $xsway), [single]($canvas/2 + 8 + $bob))
  $g.RotateTransform([single]$angle)
  $g.DrawImage($master, [single](-$dw/2), [single](-$dh/2), [single]$dw, [single]$dh)
  $g.Restore($st); $g.Dispose()
  $frames.Add($bmp)
}
[Mascot]::SaveAniGif((Join-Path $dir 'mascot-animated.gif'), $frames.ToArray(), 8, 0)
foreach($f in $frames){ $f.Dispose() }
Write-Host "GIF created: mascot-animated.gif"

$master.Dispose()
Get-ChildItem $dir -File | Where-Object { $_.Name -like 'mascot*' } | Select-Object Name, Length
