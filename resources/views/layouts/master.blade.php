<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Document</title>
    @vite(['public/css/style.css', 'resources/js/app.js'])

</head>
<body>
    @include('layouts.header')
    @yield('content')
    @include('layouts.footer')
    
</body>
</html>