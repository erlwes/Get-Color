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
    0.0.5

.NOTES
    ...

.EXAMPLE
    Get-Color
    
#>

New-Alias -Name Color -Value Get-Color

# Helper to poll mouse button state without blocking the UI
$CSharpGetAsyncKeyState = @"
using System;
using System.Runtime.InteropServices;
public static class Native {
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
}
"@

Function Get-Color {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
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
    $Form.Text = 'Double click values to copy'
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
    $ValueHex.Add_DoubleClick({
        [System.Windows.Forms.Clipboard]::SetText($ValueHex.Text)
        $ValueHex.ForeColor = [System.Drawing.Color]::White
        $ValueHex.Refresh()

        $T = New-Object System.Windows.Forms.Timer
        $T.Interval = 200
        $T.Add_Tick({
            param($sender, $e)
            try {
                $sender.Stop()
                $sender.Dispose()
            } catch {}
            $ValueHex.ForeColor = [System.Drawing.Color]::FromArgb(100,100,100)
        })
        $T.Start()
    })
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
    $ValueRGB.Add_DoubleClick({
        [System.Windows.Forms.Clipboard]::SetText($ValueRGB.Text)
        $ValueRGB.ForeColor = [System.Drawing.Color]::White
        $ValueRGB.Refresh()

        $T = New-Object System.Windows.Forms.Timer
        $T.Interval = 200
        $T.Add_Tick({
            param($sender, $e)
            try {
                $sender.Stop()
                $sender.Dispose()
            } catch {}
            $ValueRGB.ForeColor = [System.Drawing.Color]::FromArgb(100,100,100)
        })
        $T.Start()
    })
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
    }

    # Show system Color dialog. Set preview color and add hex to clipboard when clicking ok.
    $Button_ColorDialog.Add_Click({

        $ColorDialog = New-Object System.Windows.Forms.ColorDialog
        $ColorDialog.FullOpen = $true
        $ColorDialog.AnyColor = $true

        if ($ColorDialog.ShowDialog() -eq 'OK') {
            & $ShowColor $ColorDialog.Color
            [System.Windows.Forms.Clipboard]::SetText($ValueHex.Text)
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
            #
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

    


    # Allow closing form with escape key
    $Form.Add_KeyDown({
        if ($_.KeyCode -eq 'Escape') {
            $Form.Close()
        }
    })

    [System.Windows.Forms.Application]::EnableVisualStyles()
    & $ShowColor ([System.Drawing.Color]::FromArgb(255, 32, 32, 32))
    [void]$Form.ShowDialog()
    
}

