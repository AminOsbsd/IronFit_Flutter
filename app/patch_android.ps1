# Autorise HTTP (serveur local) et Internet sur Android
$f = 'android\app\src\main\AndroidManifest.xml'
if (Test-Path $f) {
  $t = Get-Content $f -Raw
  if ($t -notmatch 'usesCleartextTraffic') {
    $t = $t -replace '<application', ('<uses-permission android:name="android.permission.INTERNET"/>' + "`n    " + '<application android:usesCleartextTraffic="true"')
    Set-Content $f $t
  }
}
