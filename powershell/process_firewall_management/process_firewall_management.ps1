Add-Type -AssemblyName System.Windows.Forms

function Show-BlockProcessGUI {
    # Opret hovedvinduet
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Process Firewall Management"
    $form.Size = New-Object System.Drawing.Size(465, 450)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $false  # Forhindrer brugeren i at maksimere vinduet
    $form.MinimizeBox = $false  # Valgfrit: Skjuler minimere-knappen, hvis du ønsker det


    # Opret listeboks til aktive processer
    $labelProcess = New-Object System.Windows.Forms.Label
    $labelProcess.Text = "Process liste"
    $labelProcess.Location = New-Object System.Drawing.Point(10, 10)
    $labelProcess.AutoSize = $false
    $labelProcess.Size = New-Object System.Drawing.Size(200, 15)
    $form.Controls.Add($labelProcess)

    $processListBox = New-Object System.Windows.Forms.ListBox
    $processListBox.Size = New-Object System.Drawing.Size(200, 200)
    $processListBox.Location = New-Object System.Drawing.Point(10, 30)
    $form.Controls.Add($processListBox)

    # Fyld listeboksen med aktive processer
    $processes = Get-Process | Sort-Object ProcessName
    foreach ($process in $processes) {
        $processListBox.Items.Add("$($process.ProcessName) (PID: $($process.Id))")
    }

    # Input til tid i sekunder
    $labelTime = New-Object System.Windows.Forms.Label
    $labelTime.Text = "Tid i sekunder"
    $labelTime.Size = New-Object System.Drawing.Size(100, 15)
    $labelTime.Location = New-Object System.Drawing.Point(250, 30)
    $form.Controls.Add($labelTime)

    $timeTextBox = New-Object System.Windows.Forms.TextBox
    $timeTextBox.Size = New-Object System.Drawing.Size(200, 20)
    $timeTextBox.Location = New-Object System.Drawing.Point(250, 50)
    $form.Controls.Add($timeTextBox)

    # Begræns input i $timeTextBox til kun at tillade tal
    $timeTextBox.Add_KeyPress({
        param($sender, $e)
        if (-not ([char]::IsDigit($e.KeyChar) -or $e.KeyChar -eq [char][System.Windows.Forms.Keys]::Back)) {
            $e.Handled = $true
        }
    })

    # Checkbox til at bestemme om regler skal slettes automatisk
    $keepRulesCheckbox = New-Object System.Windows.Forms.CheckBox
    $keepRulesCheckbox.Text = "Behold regler efter timeout"
    $keepRulesCheckbox.Location = New-Object System.Drawing.Point(250, 80)
    $keepRulesCheckbox.Size = New-Object System.Drawing.Size(200, 20)
    $form.Controls.Add($keepRulesCheckbox)

    # Event-handler til at deaktivere tid-input, når checkbox er markeret
    $keepRulesCheckbox.Add_CheckedChanged({
    if ($keepRulesCheckbox.Checked) {
        $timeTextBox.Enabled = $false
        $timeTextBox.BackColor = [System.Drawing.Color]::LightGray
    } else {
        $timeTextBox.Enabled = $true
        $timeTextBox.BackColor = [System.Drawing.Color]::White
    }
    })


    # Opret output-vindue til status
    $outputTextBox = New-Object System.Windows.Forms.TextBox
    $outputTextBox.Size = New-Object System.Drawing.Size(440, 100)
    $outputTextBox.Location = New-Object System.Drawing.Point(10, 300)
    $outputTextBox.Multiline = $true
    $outputTextBox.ReadOnly = $true
    $form.Controls.Add($outputTextBox)

    # Opret "Pause Process" knap
    $pauseButton = New-Object System.Windows.Forms.Button
    $pauseButton.Text = "Pause process med firewall regler"
    $pauseButton.Size = New-Object System.Drawing.Size(200, 40)
    $pauseButton.Location = New-Object System.Drawing.Point(250, 110)
    $form.Controls.Add($pauseButton)
        # Opret "Tæl firewall regler" knap
    $countRulesButton = New-Object System.Windows.Forms.Button
    $countRulesButton.Text = "Tæl firewall regler for proces"
    $countRulesButton.Size = New-Object System.Drawing.Size(200, 40)
    $countRulesButton.Location = New-Object System.Drawing.Point(250, 150)
    $form.Controls.Add($countRulesButton)

    # Opret "Fjern firewall regler" knap
    $removeRulesButton = New-Object System.Windows.Forms.Button
    $removeRulesButton.Text = "Fjern firewall regler for proces"
    $removeRulesButton.Size = New-Object System.Drawing.Size(200, 40)
    $removeRulesButton.Location = New-Object System.Drawing.Point(250, 190)
    $form.Controls.Add($removeRulesButton)

    # Funktion til at oprette og eventuelt fjerne firewall-regler
    $pauseButton.Add_Click({
    $outputTextBox.Clear()

    # Validér valg af proces
    if ($processListBox.SelectedItem -eq $null) {
        [System.Windows.Forms.MessageBox]::Show("Vælg venligst en proces.")
        return
    }

    # Validér input af tid kun hvis checkbox ikke er markeret
    $timeInSeconds = 0
    if (-not $keepRulesCheckbox.Checked) {
        if (-not [int]::TryParse($timeTextBox.Text, [ref]$timeInSeconds) -or $timeInSeconds -le 0) {
            [System.Windows.Forms.MessageBox]::Show("Indtast en gyldig tid i sekunder.")
            return
        }
    }


        # Ekstraher Process ID og navn
        $selectedText = $processListBox.SelectedItem.ToString()
        $processId = [int]($selectedText -replace ".*PID: (\d+)\).*", '$1')
        $processName = $selectedText -replace " \(PID:.*", ''

        # Hent IP-adresser for processen
        $connections = Get-NetTCPConnection | Where-Object { $_.OwningProcess -eq $processId -and $_.RemoteAddress -ne "0.0.0.0" }
        $ipAddresses = $connections | Select-Object -ExpandProperty RemoteAddress -Unique
        $outputTextBox.AppendText("Antal fundne IP-adresser for $($processName): $($ipAddresses.Count)`r`n")

        # Bloker IP-adresserne med firewall-regler
        foreach ($ip in $ipAddresses) {
            $outboundRuleName = "Block_$($processName)_Outbound_$($ip)"
            $inboundRuleName = "Block_$($processName)_Inbound_$($ip)"

            # Tjek og opret kun reglen, hvis den ikke allerede findes
            if (-not (Get-NetFirewallRule | Where-Object { $_.DisplayName -eq $outboundRuleName })) {
                try {
                    New-NetFirewallRule -DisplayName $outboundRuleName `
                        -Direction Outbound `
                        -RemoteAddress $ip `
                        -Action Block
                    $outputTextBox.AppendText("Blokeret udgående trafik til $($ip) for $($processName).`r`n")
                } catch {
                    $outputTextBox.AppendText("Fejl ved oprettelse af udgående regel for $($ip): $($_.Exception.Message)`r`n")
                }
            }

            if (-not (Get-NetFirewallRule | Where-Object { $_.DisplayName -eq $inboundRuleName })) {
                try {
                    New-NetFirewallRule -DisplayName $inboundRuleName `
                        -Direction Inbound `
                        -RemoteAddress $ip `
                        -Action Block
                    $outputTextBox.AppendText("Blokeret indgående trafik fra $($ip) for $($processName).`r`n")
                } catch {
                    $outputTextBox.AppendText("Fejl ved oprettelse af indgående regel for $($ip): $($_.Exception.Message)`r`n")
                }
            }
        }

        # Udfør nedtælling og sletning af regler, hvis checkbox ikke er markeret
        if (-not $keepRulesCheckbox.Checked) {
            for ($i = $timeInSeconds; $i -gt 0; $i--) {
                $outputTextBox.AppendText("Nedtælling: $($i) sekunder tilbage`r`n")
                Start-Sleep -Seconds 1
                [System.Windows.Forms.Application]::DoEvents()
            }

            # Fjern firewall-reglerne efter nedtælling
            foreach ($ip in $ipAddresses) {
                Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Block_$($processName)_*_$($ip)" } | Remove-NetFirewallRule
                $outputTextBox.AppendText("Fjernede blokering for IP $($ip) for $($processName).`r`n")
            }
        }
    })

    # Funktion til at tælle firewall-regler for processen
    $countRulesButton.Add_Click({
        if ($processListBox.SelectedItem -eq $null) {
            [System.Windows.Forms.MessageBox]::Show("Vælg venligst en proces.")
            return
        }

        $selectedText = $processListBox.SelectedItem.ToString()
        $processName = $selectedText -replace " \(PID:.*", ''
        $outboundRules = (Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Block_$($processName)_Outbound_*" }).Count
        $inboundRules = (Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Block_$($processName)_Inbound_*" }).Count
        $totalRules = $outboundRules + $inboundRules

        $outputTextBox.Clear()
        $outputTextBox.AppendText("Antal firewall-regler for $($processName): $($totalRules)`r`n")
    })

    # Funktion til at fjerne alle firewall-regler for den valgte proces
    $removeRulesButton.Add_Click({
    $outputTextBox.Clear()
    if ($processListBox.SelectedItem -eq $null) {
        [System.Windows.Forms.MessageBox]::Show("Vælg venligst en proces.")
        return
    }

    $selectedText = $processListBox.SelectedItem.ToString()
    $processName = $selectedText -replace " \(PID:.*", ''

    # Hent alle firewall-regler for den valgte proces uanset IP-adresse
    $rulesToRemove = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Block_$($processName)_*" }
    
    if ($rulesToRemove) {
    # Loop gennem hver regel og fjern den med output for hver fjernet regel
    foreach ($rule in $rulesToRemove) {
        Remove-NetFirewallRule -InputObject $rule
        $outputTextBox.AppendText("Fjernede blokering: $($rule.DisplayName) for processen $($processName).`r`n")
    }
    } else {
    $outputTextBox.AppendText("Ingen blokeringer fundet for processen $($processName).`r`n")
    }
    })



    # Vis formularen
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}

Show-BlockProcessGUI
