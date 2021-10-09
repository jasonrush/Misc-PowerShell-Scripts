1..254 | %{
    $Computer = "192.168.1.$($_)"
    $Port = 80

        # Create a Net.Sockets.TcpClient object to use for
        # checking for open TCP ports.
        $Socket = New-Object Net.Sockets.TcpClient

        # Suppress error messages
        $ErrorActionPreference = 'SilentlyContinue'

        # Try to connect
        $Socket.Connect($Computer, $Port)

        # Make error messages visible again
        $ErrorActionPreference = 'Continue'

        # Determine if we are connected.
        if ($Socket.Connected) {
            "${Computer}: Port $Port is open"
#            start "http://$Computer/" # Uncommenting this line will automatically open any found webservers in a browser.
            $Socket.Close()
        }
        else {
            "${Computer}: Port $Port is closed or filtered"  
        }
        # Apparently resetting the variable between iterations is necessary.
        $Socket = $null
}
