<#
.SYNOPSIS
    Simple colorpicker

.DESCRIPTION
    Simple colorpicker made using Windows Forms in PowerShell. Select pixel on screen and get HEX + RGB color value.

.AUTHOR
    EW

.COPYRIGHT
    No

.LICENSE
    None

.VERSION
    0.1.0

.NOTES
    0.1.0 - Extended C# block to suppress left mouse click while color-sampling, so that it only samples, but does not click the element on screen that one samples from.

.EXAMPLE
    Get-Color
    
#>

New-Alias -Name Color -Value Get-Color

Function Get-Color {
    Start-Job -ScriptBlock {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        # Helper to poll mouse button state without blocking the UI, while suppressing the click, but not the sampling of color.
        $CSharpGetAsyncKeyState = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public static class Native {
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);

  // Low-level mouse hook constants
  private const int WH_MOUSE_LL = 14;
  private const int WM_LBUTTONDOWN = 0x0201;
  private const int WM_LBUTTONUP   = 0x0202;
  private const int WM_LBUTTONDBLCLK = 0x0203;

  private static IntPtr _mouseHook = IntPtr.Zero;
  private static HookProc _proc = HookCallback;
  private static bool _suppress = false;
  private static volatile bool _click = false;

  private delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

  [DllImport("user32.dll", SetLastError = true)]
  private static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);

  [DllImport("user32.dll", SetLastError = true)]
  [return: MarshalAs(UnmanagedType.Bool)]
  private static extern bool UnhookWindowsHookEx(IntPtr hhk);

  [DllImport("user32.dll")]
  private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

  [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
  private static extern IntPtr GetModuleHandle(string lpModuleName);

  public static void EnableClickSuppress() {
    _suppress = true;
    if (_mouseHook == IntPtr.Zero) {
      // For WH_MOUSE_LL, pass the host process module handle
      IntPtr hMod = GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName);
      _mouseHook = SetWindowsHookEx(WH_MOUSE_LL, _proc, hMod, 0);
    }
  }

  public static void DisableClickSuppress() {
    _suppress = false;
    if (_mouseHook != IntPtr.Zero) {
      UnhookWindowsHookEx(_mouseHook);
      _mouseHook = IntPtr.Zero;
    }
    _click = false;
  }

  // Polled by PowerShell to detect the swallowed left-click
  public static bool TryConsumeClick() {
    bool was = _click;
    _click = false;
    return was;
  }

  private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
    if (nCode >= 0 && _suppress) {
      int msg = unchecked((int)wParam);
      if (msg == WM_LBUTTONDOWN || msg == WM_LBUTTONUP || msg == WM_LBUTTONDBLCLK) {
        _click = true;      // record the click for the picker loop
        return (IntPtr)1;   // swallow it so the target app doesn't receive it
      }
    }
    return CallNextHookEx(_mouseHook, nCode, wParam, lParam);
  }
}
"@

        Add-Type -Language CSharp -TypeDefinition $CSharpGetAsyncKeyState

        Function Get-PixelColorAtCursor {
            $Position = [System.Windows.Forms.Cursor]::Position
            $Bitmap = New-Object System.Drawing.Bitmap 1,1
            $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
            $Graphics.CopyFromScreen($Position, [System.Drawing.Point]::Empty, $Bitmap.Size)
            $Graphics.Dispose()
            $C = $Bitmap.GetPixel(0,0)
            $Bitmap.Dispose()
            $C
        }

        $Form = New-Object System.Windows.Forms.Form

        if ($isCoreCLR) {
            $Form.Text = 'Click values to copy'
        }
        else {
            $Form.Text = 'Doubleclick values to copy'
        }
        
        $Form.StartPosition = 'CenterScreen'
        $Form.Size = New-Object System.Drawing.Size(380,180)
        $Form.FormBorderStyle = 'FixedDialog'
        $Form.MaximizeBox = $false
        $Form.KeyPreview = $true

        $Preview = New-Object System.Windows.Forms.Panel
        $Preview.Size = New-Object System.Drawing.Size(80,80)
        $Preview.Location = New-Object System.Drawing.Point(20,20)
        $Preview.BorderStyle = 'FixedSingle'              
        $Form.Controls.Add($Preview)

        $LabelHex = New-Object System.Windows.Forms.Label
        $LabelHex.AutoSize = $true
        $LabelHex.Location = New-Object System.Drawing.Point(120,30)
        $LabelHex.Text = 'HEX:'
        $Form.Controls.Add($LabelHex)

        $ValueHex = New-Object System.Windows.Forms.Label
        $ValueHex.AutoSize = $true
        $ValueHex.Location = New-Object System.Drawing.Point(160,30)
        $ValueHex.Add_MouseEnter({ $ValueHex.ForeColor = [System.Drawing.Color]::FromArgb(100,100,100) })
        $ValueHex.Add_MouseLeave({ $ValueHex.ForeColor = [System.Drawing.Color]::FromArgb(0,0,0) })
        if ($isCoreCLR) {
            $ValueHex.Add_Click({        
                $ValueHex.Text | Set-Clipboard
                [System.Windows.Forms.MessageBox]::Show(
                    "Copied '$($ValueHex.Text)' to clipboard",
                    "Copied",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null            
            })
        }
        else {
            $ValueHex.Add_DoubleClick({        
                $ValueHex.Text | Set-Clipboard
                [System.Windows.Forms.MessageBox]::Show(
                    "Copied '$($ValueHex.Text)' to clipboard",
                    "Copied",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null            
            })
        }
        
        $Form.Controls.Add($ValueHex)
        
        $LabelRGB = New-Object System.Windows.Forms.Label
        $LabelRGB.AutoSize = $true
        $LabelRGB.Location = New-Object System.Drawing.Point(120,60)
        $LabelRGB.Text = 'RGB:'
        $Form.Controls.Add($LabelRGB)

        $ValueRGB = New-Object System.Windows.Forms.Label
        $ValueRGB.AutoSize = $true
        $ValueRGB.Location = New-Object System.Drawing.Point(160,60)
        $ValueRGB.Add_MouseEnter({ $ValueRGB.ForeColor = [System.Drawing.Color]::FromArgb(100,100,100) })
        $ValueRGB.Add_MouseLeave({ $ValueRGB.ForeColor = [System.Drawing.Color]::FromArgb(0,0,0) })
        if ($isCoreCLR) {
            $ValueRGB.Add_Click({        
                $ValueRGB.Text | Set-Clipboard
                [System.Windows.Forms.MessageBox]::Show(
                    "Copied '$($ValueRGB.Text)' to clipboard",
                    "Copied",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null            
            })
        }
        else {
            $ValueRGB.Add_DoubleClick({        
                $ValueRGB.Text | Set-Clipboard
                [System.Windows.Forms.MessageBox]::Show(
                    "Copied '$($ValueRGB.Text)' to clipboard",
                    "Copied",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null            
            })
        }
        $Form.Controls.Add($ValueRGB)

        $Button_ColorDialog = New-Object System.Windows.Forms.Button
        $Button_ColorDialog.Text = "Colorpicker"
        $Button_ColorDialog.Size = New-Object System.Drawing.Size(110,30)
        $Button_ColorDialog.Location = New-Object System.Drawing.Point(120,100)
        $Form.Controls.Add($Button_ColorDialog)

        $Button_SampleScreen = New-Object System.Windows.Forms.Button
        $Button_SampleScreen.Text = "Sample screen"
        $Button_SampleScreen.Size = New-Object System.Drawing.Size(110,30)
        $Button_SampleScreen.Location = New-Object System.Drawing.Point(240,100)
        $Form.Controls.Add($Button_SampleScreen)

        # Helpers to show a color
        $ShowColor = {
            param([System.Drawing.Color]$C)
            $Preview.BackColor = $C
            $ValueHex.Text  = ("#{0:X2}{1:X2}{2:X2}" -f $C.R,$C.G,$C.B)
            $ValueRGB.Text = ("{0},{1},{2}" -f $C.R,$C.G,$C.B)
            $ValueHex.Text | Set-Clipboard
        }

        # Show system Color dialog. Set preview color and add hex to clipboard when clicking ok.
        $Button_ColorDialog.Add_Click({

            $ColorDialog = New-Object System.Windows.Forms.ColorDialog
            $ColorDialog.FullOpen = $true
            $ColorDialog.AnyColor = $true

            if ($ColorDialog.ShowDialog() -eq 'OK') {
                & $ShowColor $ColorDialog.Color
                $ValueHex.Text | Set-Clipboard
                $ColorDialog.Dispose()
            }

        })

        # Eyedropper triggers when clicking the "Sample Screen" button
        $Button_SampleScreen.Add_Click({
            
            # Parameters
            $SampleSize = 30  # 30x30 pixels around the cursor
            $LoupeScale = 4                  
            $LoupeSize  = $SampleSize * $LoupeScale  # 120x120 magnify view
            $LoupeOffset = New-Object System.Drawing.Point(24,24)  # Move the magnify preview away from the mouse pointer

            # Create the magnify window
            $Loupe = New-Object System.Windows.Forms.Form
            $Loupe.FormBorderStyle = 'None'
            $Loupe.ShowInTaskbar = $false
            $Loupe.TopMost = $true
            $Loupe.StartPosition = 'Manual'
            $Loupe.Size = New-Object System.Drawing.Size($LoupeSize, $LoupeSize)
            $Loupe.BackColor = [System.Drawing.Color]::Black  # just in case we see behind image
            $Loupe.Opacity = 0.98

            # This will contain the magnify image
            $LoupeImg = $null

            # Timer used to update position + bitmap from background
            $Timer = New-Object System.Windows.Forms.Timer
            $Timer.Interval = 16   # ~60 FPS

            # Pre-create bitmaps to avoid allocations on every tick (60 times per second)
            $PixelFormat = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb    
            $SrcBmp  = New-Object System.Drawing.Bitmap ($SampleSize, $SampleSize, $PixelFormat)
            $DstBmp  = New-Object System.Drawing.Bitmap ($LoupeSize, $LoupeSize, $PixelFormat)

            # Screen bounds (multi-monitor aware)
            $VirtualScreen = [System.Windows.Forms.SystemInformation]::VirtualScreen

            #Logic that runs over and over when picker is active:
            $UpdateLoupe = {
                # Where's the pointer?
                $Position = [System.Windows.Forms.Cursor]::Position

                # Keep the 50x50 capture fully on-screen
                $SrcX = [Math]::Max($VirtualScreen.Left,  [Math]::Min($Position.X - [int]($SampleSize/2), $VirtualScreen.Right  - $SampleSize))
                $SrcY = [Math]::Max($VirtualScreen.Top,   [Math]::Min($Position.Y - [int]($SampleSize/2), $VirtualScreen.Bottom - $SampleSize))

                # Capture 50x50 around cursor
                $GraphicsSrc = [System.Drawing.Graphics]::FromImage($SrcBmp)
                $GraphicsSrc.CopyFromScreen($SrcX, $SrcY, 0, 0, $SrcBmp.Size)
                $GraphicsSrc.Dispose()

                # Scale up to the loupe size (nearest-neighbor for crisp pixels)
                $GraphicsDst = [System.Drawing.Graphics]::FromImage($dstBmp)
                $GraphicsDst.CompositingMode  = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $GraphicsDst.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed
                $GraphicsDst.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
                $GraphicsDst.PixelOffsetMode  = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
                $GraphicsDst.SmoothingMode    = [System.Drawing.Drawing2D.SmoothingMode]::None
                $GraphicsDst.Clear([System.Drawing.Color]::Black)
                $Rectangle = New-Object System.Drawing.Rectangle(0,0,$LoupeSize,$LoupeSize)
                $GraphicsDst.DrawImage($SrcBmp, $Rectangle)

                # Draw a crosshair in center of the loupe
                $Pen1 = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 1
                $Pen2 = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), 1
                $CX = [int]($LoupeSize/2)
                $CY = [int]($LoupeSize/2)

                # First white, then black (contrast)
                $GraphicsDst.DrawLine($Pen1, $CX, 0, $CX, $LoupeSize)
                $GraphicsDst.DrawLine($Pen1, 0, $CY, $LoupeSize, $CY)
                $GraphicsDst.DrawLine($Pen2, $CX+1, 0, $CX+1, $LoupeSize)
                $GraphicsDst.DrawLine($Pen2, 0, $CY+1, $LoupeSize, $CY+1)        
                $Pen1.Dispose()
                $Pen2.Dispose()
                $GraphicsDst.Dispose()

                # Swap into the loupe form
                if ($LoupeImg) { $Loupe.BackgroundImage.Dispose() }
                $LoupeImg = [System.Drawing.Bitmap]$dstBmp.Clone()
                $Loupe.BackgroundImage = $LoupeImg
                $Loupe.BackgroundImageLayout = 'Stretch'

                # Position the loupe near the cursor (clamp on-screen)
                $LocationX = $Position.X + $LoupeOffset.X
                $LocationY = $Position.Y + $LoupeOffset.Y
                if ($LocationX + $Loupe.Width  -gt $VirtualScreen.Right)  { $LocationX = $Position.X - $LoupeOffset.X - $Loupe.Width }
                if ($LocationY + $Loupe.Height -gt $VirtualScreen.Bottom) { $LocationY = $Position.Y - $LoupeOffset.Y - $Loupe.Height }
                if ($LocationX -lt $VirtualScreen.Left)   { $LocationX = $VirtualScreen.Left }
                if ($LocationY -lt $VirtualScreen.Top)    { $LocationY = $VirtualScreen.Top  }
                $Loupe.Location = New-Object System.Drawing.Point($LocationX, $LocationY)
            }

            $TickHandler = {
                # Keep UI awake
                [System.Windows.Forms.Application]::DoEvents()
                & $UpdateLoupe
            }

            try {
                # Remember and hide the picker window so it doesn't block the pixel under cursor
                $WasTopMost = $Form.TopMost
                $Form.TopMost = $false
                $Form.Hide()
                Start-Sleep -Milliseconds 60

                # Suppress mouse click (just sample, dont click)
                [Native]::EnableClickSuppress()

                # Show loupe and start updating
                $Loupe.Show()
                $Timer.Add_Tick($TickHandler)
                $Timer.Start()

                # Crosshair cursor while picking
                [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Cross

                # Wait for next left mouse button press (VK_LBUTTON = 0x01)
                while (-not [Native]::TryConsumeClick()) {
                    [System.Windows.Forms.Application]::DoEvents()
                    Start-Sleep -Milliseconds 10
                    if ([Native]::GetAsyncKeyState(0x1B) -band 0x8000) { throw 'Canceled' }
                }

                # Final read uses your existing helper
                $C = Get-PixelColorAtCursor
                & $ShowColor $C
            }
            catch {
                #
            }
            finally {
                # Stop suppressing mouse clicks
                [Native]::DisableClickSuppress() 

                # Stop timer and clean up loupe resources
                $Timer.Stop()
                $Timer.Remove_Tick($TickHandler)
                $Timer.Dispose()

                if ($LoupeImg) {
                    $Loupe.BackgroundImage.Dispose()
                    $LoupeImg.Dispose()
                }

                $Loupe.Close()
                $Loupe.Dispose()
                $SrcBmp.Dispose()
                $DstBmp.Dispose()

                # Restore cursor and main form
                [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
                $Form.Show()
                $Form.TopMost = $WasTopMost
                $Form.Activate()
            }
        })


        # Add close using escape
        $Form.Add_KeyDown({
            if ($_.KeyCode -eq 'Escape') {
                $Form.Close()
            }
        })

        [System.Windows.Forms.Application]::EnableVisualStyles()
        & $ShowColor ([System.Drawing.Color]::FromArgb(255, 32, 32, 32))
        [void]$Form.ShowDialog()
    } | Out-Null
}
