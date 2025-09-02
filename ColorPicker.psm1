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
    0.0.3

.NOTES
    ...

.EXAMPLE
    Get-Color
    
#>


# Helper to poll mouse button state without blocking the UI

New-Alias -Name Color -Value Get-Color

$CSharpGetAsyncKeyState = @"
using System;
using System.Runtime.InteropServices;
public static class Native {
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
}
"@

Add-Type -Language CSharp -TypeDefinition $CSharpGetAsyncKeyState
Function Get-Color {
    Start-ThreadJob -Name "ColorPicker" -ScriptBlock {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

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
        $Form.Text = 'Color Picker'
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

        $Label_Hex = New-Object System.Windows.Forms.Label
        $Label_Hex.AutoSize = $true
        $Label_Hex.Location = New-Object System.Drawing.Point(120,30)
        $Label_Hex.Add_MouseEnter({ $Label_Hex.ForeColor = [System.Drawing.Color]::FromArgb(100,100,100) })
        $Label_Hex.Add_MouseLeave({ $Label_Hex.ForeColor = [System.Drawing.Color]::FromArgb(0,0,0) })
        $Label_Hex.Add_Click({
            $ClipB = $Label_Hex.Text -replace "^HEX: "
            if ($ClipB) {
                [System.Windows.Forms.Clipboard]::SetText($ClipB)
            }
            $Label_Hex.ForeColor = [System.Drawing.Color]::FromArgb(255,255,255)
            Start-Sleep -Seconds 0.2    
            $Label_Hex.ForeColor = [System.Drawing.Color]::FromArgb(100,100,100)
        })
        $Form.Controls.Add($Label_Hex)

        $Label_RGB = New-Object System.Windows.Forms.Label
        $Label_RGB.AutoSize = $true
        $Label_RGB.Location = New-Object System.Drawing.Point(120,60)
        $Label_RGB.Add_MouseEnter({ $Label_RGB.ForeColor = [System.Drawing.Color]::FromArgb(100,100,100) })
        $Label_RGB.Add_MouseLeave({ $Label_RGB.ForeColor = [System.Drawing.Color]::FromArgb(0,0,0) })
        $Label_RGB.Add_Click({
            $ClipB = $Label_RGB.Text -replace "^RGB: " -replace "\w=" -replace "\s", ','
            if ($ClipB) {
                [System.Windows.Forms.Clipboard]::SetText($ClipB)
            }
            $Label_RGB.ForeColor = [System.Drawing.Color]::FromArgb(255,255,255)
            Start-Sleep -Seconds 0.2    
            $Label_RGB.ForeColor = [System.Drawing.Color]::FromArgb(100,100,100)
        })
        $Form.Controls.Add($Label_RGB)

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
            $Label_Hex.Text  = "HEX: " + ("#{0:X2}{1:X2}{2:X2}" -f $C.R,$C.G,$C.B)
            $Label_RGB.Text = "RGB: " + ("R={0} G={1} B={2}" -f $C.R,$C.G,$C.B)
        }

        # Show system Color dialog. Set preview color and add hex to clipboard when clicking ok.
        $Button_ColorDialog.Add_Click({

            $ColorDialog = New-Object System.Windows.Forms.ColorDialog
            $ColorDialog.FullOpen = $true
            $ColorDialog.AnyColor = $true

            if ($ColorDialog.ShowDialog() -eq 'OK') {
                & $ShowColor $ColorDialog.Color
                $ClipB = $Label_Hex.Text -replace "^HEX: "
                if ($ClipB) {
                    [System.Windows.Forms.Clipboard]::SetText($ClipB)
                }
                $ColorDialog.Dispose()
            }

        })

        # Eyedropper triggers when clicking the "Sample Screen" button
        $Button_SampleScreen.Add_Click({
            
            # Parameters
            $SampleSize = 30                 # 30x30 pixels around the cursor
            $LoupeScale = 4                  
            $LoupeSize  = $SampleSize * $LoupeScale # 120x120 magnify view
            $LoupeOffset = New-Object System.Drawing.Point(24,24)  # Move the magnify preview away from the mouse pointer

            # Create the magnify window
            $Loupe = New-Object System.Windows.Forms.Form
            $Loupe.FormBorderStyle = 'None'
            $Loupe.ShowInTaskbar = $false
            $Loupe.TopMost = $true
            $Loupe.StartPosition = 'Manual'
            $Loupe.Size = New-Object System.Drawing.Size($LoupeSize, $LoupeSize)
            $Loupe.BackColor = [System.Drawing.Color]::Black    # just in case we see behind image
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

                # Show loupe and start updating
                $Loupe.Show()
                $Timer.Add_Tick($TickHandler)
                $Timer.Start()

                # Crosshair cursor while picking        
                [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Cross

                # Wait for next *press* of the left mouse button (VK_LBUTTON = 0x01)
                while ($true) {
                    [System.Windows.Forms.Application]::DoEvents()
                    Start-Sleep -Milliseconds 10

                    $State = [Native]::GetAsyncKeyState(0x01)
                    if (($State -band 0x8000) -ne 0) {
                        while(([Native]::GetAsyncKeyState(0x01) -band 0x8000) -ne 0) {
                            Start-Sleep -Milliseconds 5
                        }
                        break
                    }

                    # Allow cancel with Esc
                    if ([Native]::GetAsyncKeyState(0x1B) -band 0x8000) {
                        throw 'Canceled'
                    }
                }

                # Final read uses your existing helper
                $C = Get-PixelColorAtCursor
                & $ShowColor $C
            }
            catch {
                if ($_.Exception.Message -eq 'Canceled') {
                    $Label_Hex.Text = 'Pick canceled'
                    $Label_RGB.Text = ''
                }
            }
            finally {
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

        # Copy HEX to clipboard if preview color is clicked
        $Preview.Add_Click({
            $ClipB = $Label_Hex.Text -replace "^HEX: "
            if ($ClipB) {
                [System.Windows.Forms.Clipboard]::SetText($ClipB)
            }
        })


        # Allow closing form with escape key
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