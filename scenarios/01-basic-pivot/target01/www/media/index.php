<?php

$message = "";
$uploadedFile = "";

if ($_SERVER["REQUEST_METHOD"] === "POST" && isset($_FILES["media"])) {

    $upload = $_FILES["media"];
    $filename = basename($upload["name"]);

    $allowed = [
        ".jpg",
        ".jpeg",
        ".png",
        ".gif",
        ".pdf"
    ];

    $valid = false;

    /*
     * INTENTIONALLY VULNERABLE
     *
     * MediaTools 1.3 performs legacy filename validation by checking
     * whether an approved extension appears anywhere in the filename.
     *
     * This behavior exists only for the Enterprise Pivot Lab.
     */

    foreach ($allowed as $extension) {
        if (stripos($filename, $extension) !== false) {
            $valid = true;
            break;
        }
    }

    if (!$valid) {

        $message = "Upload rejected: unsupported media type.";

    } elseif ($upload["error"] !== UPLOAD_ERR_OK) {

        $message = "Upload failed.";

    } else {

        $destination = __DIR__ . "/../uploads/" . $filename;

        if (move_uploaded_file($upload["tmp_name"], $destination)) {
            $message = "Upload completed.";
            $uploadedFile = "/uploads/" . rawurlencode($filename);
        } else {
            $message = "Unable to store uploaded file.";
        }
    }
}

?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Northstar MediaTools</title>
    <link rel="stylesheet" href="/assets/style.css">
</head>

<body>

<header>
    <div class="brand">NORTHSTAR</div>
    <div class="subtitle">MediaTools 1.3</div>

    <nav>
        <a href="/">Home</a>
        <a href="/media/">Media</a>
    </nav>
</header>

<main>

<section class="card">

    <h2>Media Library</h2>

    <p>
        Upload an image or document to the internal media library.
    </p>

    <p>
        Supported formats: JPG, JPEG, PNG, GIF, PDF
    </p>

    <form method="POST" enctype="multipart/form-data">

        <p>
            <input type="file" name="media" required>
        </p>

        <button type="submit">Upload Media</button>

    </form>

    <?php if ($message): ?>

        <p>
            <strong><?= htmlspecialchars($message) ?></strong>
        </p>

    <?php endif; ?>

    <?php if ($uploadedFile): ?>

        <p>
            Media URL:
            <a href="<?= htmlspecialchars($uploadedFile) ?>">
                <?= htmlspecialchars($uploadedFile) ?>
            </a>
        </p>

    <?php endif; ?>

</section>

</main>

<footer>
    MediaTools 1.3 // Northstar CMS
</footer>

</body>
</html>
