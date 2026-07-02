<?php
declare(strict_types=1);

function find_app_root(): string
{
    $candidates = [
        getcwd(),
        dirname(__DIR__, 2),
        '/var/www/html',
        '/var/www/html/snipe-it',
        '/app',
    ];

    foreach ($candidates as $root) {
        if (!$root) {
            continue;
        }
        $asset = rtrim($root, '/\\') . '/app/Models/Asset.php';
        if (is_file($asset)) {
            return rtrim($root, '/\\');
        }
    }

    throw new RuntimeException('Snipe-IT application root was not found.');
}

function write_if_changed(string $path, string $content): bool
{
    $old = file_get_contents($path);
    if ($old === $content) {
        return false;
    }

    $backup = $path . '.oneclick.bak';
    if (!is_file($backup)) {
        copy($path, $backup);
    }

    file_put_contents($path, $content);
    return true;
}

function patch_asset_model(string $root): bool
{
    $path = $root . '/app/Models/Asset.php';
    $content = file_get_contents($path);

    if (preg_match("/'name'\s*=>\s*\[[^\]]*'required'/", $content)) {
        echo "[OK] Asset model name validation is already required.\n";
        return false;
    }

    $updated = preg_replace(
        "/'name'\s*=>\s*\[\s*'nullable'\s*,\s*'max:255'\s*\]/",
        "'name' => ['required', 'string', 'max:255']",
        $content,
        1,
        $count
    );

    if ($count !== 1 || $updated === null) {
        throw new RuntimeException('Could not patch app/Models/Asset.php. The upstream validation rule changed.');
    }

    write_if_changed($path, $updated);
    echo "[OK] Patched Asset model name validation.\n";
    return true;
}

function patch_name_partial(string $root): bool
{
    $path = $root . '/resources/views/partials/forms/edit/name.blade.php';
    if (!is_file($path)) {
        echo "[WARN] Name partial was not found; server-side validation is still patched.\n";
        return false;
    }

    $content = file_get_contents($path);
    $updated = $content;

    $labelNeedle = <<<'BLADE'
<label for="name" class="col-md-3 control-label">{{ $translated_name }}</label>
BLADE;
    $labelReplacement = <<<'BLADE'
<label for="name" class="col-md-3 control-label">{{ $translated_name }} <span class="text-danger" aria-hidden="true">*</span></label>
BLADE;
    if (strpos($updated, 'oneclick-asset-name-required') === false && strpos($updated, $labelNeedle) !== false) {
        $updated = str_replace($labelNeedle, "<!-- oneclick-asset-name-required -->\n" . $labelReplacement, $updated);
    }

    $inputNeedle = <<<'BLADE'
<input class="form-control" style="width:100%;" type="text" name="name" aria-label="name" id="name" value="{{ old('name', $item->name) }}"{!!  (Helper::checkIfRequired($item, 'name')) ? ' required' : '' !!} maxlength="191" />
BLADE;
    $inputReplacement = <<<'BLADE'
<input class="form-control" style="width:100%;" type="text" name="name" aria-label="name" id="name" value="{{ old('name', $item->name) }}" aria-required="true" maxlength="191" />
BLADE;
    if (strpos($updated, $inputNeedle) !== false) {
        $updated = str_replace($inputNeedle, $inputReplacement, $updated);
    }

    if (write_if_changed($path, $updated)) {
        echo "[OK] Patched asset name form marker.\n";
        return true;
    }

    echo "[OK] Asset name form marker is already patched.\n";
    return false;
}

function patch_hardware_edit(string $root): bool
{
    $path = $root . '/resources/views/hardware/edit.blade.php';
    if (!is_file($path)) {
        echo "[WARN] Hardware edit view was not found; server-side validation is still patched.\n";
        return false;
    }

    $content = file_get_contents($path);
    $needle = '<div id="optional_details" class="col-md-12" style="display:none">';
    $replacement = '<div id="optional_details" class="col-md-12" style="{{ $errors->has(\'name\') ? \'\' : \'display:none\' }}">';

    if (strpos($content, $replacement) !== false) {
        echo "[OK] Optional details error display is already patched.\n";
        return false;
    }

    if (strpos($content, $needle) === false) {
        echo "[WARN] Optional details block was not found; server-side validation is still patched.\n";
        return false;
    }

    $updated = str_replace($needle, $replacement, $content);
    write_if_changed($path, $updated);
    echo "[OK] Patched optional details error display.\n";
    return true;
}

$root = find_app_root();
echo "[INFO] Snipe-IT root: {$root}\n";

patch_asset_model($root);
patch_name_partial($root);
patch_hardware_edit($root);

echo "[OK] Asset name required patch applied.\n";
