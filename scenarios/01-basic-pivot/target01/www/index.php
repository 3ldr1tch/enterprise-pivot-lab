<?php
$hostname = gethostname();
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Northstar CMS</title>
    <link rel="stylesheet" href="/assets/style.css">
</head>

<body>

<header>
    <div class="brand">NORTHSTAR</div>
    <div class="subtitle">Internal Communications Portal</div>

    <nav>
        <a href="/">Home</a>
        <a href="/media/">Media</a>
        <a href="/admin/">Administration</a>
    </nav>
</header>

<main>

<section class="hero">
    <h1>Northstar Communications</h1>

    <p>
        Internal publishing and communications platform.
    </p>
</section>

<section class="grid">

    <article class="card">
        <h2>Infrastructure Maintenance</h2>
        <span class="date">September 18, 2026</span>

        <p>
            Network maintenance for internal application services
            has been completed. Please report connectivity issues
            through the normal operations channel.
        </p>
    </article>

    <article class="card">
        <h2>Quarterly Documentation Review</h2>
        <span class="date">September 12, 2026</span>

        <p>
            Department owners should review published documents
            and remove obsolete material from the communications
            portal.
        </p>
    </article>

    <article class="card">
        <h2>Media Library Migration</h2>
        <span class="date">September 3, 2026</span>

        <p>
            The legacy media library has been migrated to the
            MediaTools component. Existing links should continue
            to function.
        </p>
    </article>

</section>

<section class="system-info">
    <strong>Node:</strong> <?= htmlspecialchars($hostname) ?>
</section>

</main>

<footer>
    Northstar CMS 2.4.1
</footer>

</body>
</html>
