#!/usr/bin/env php
<?php
echo "Start Process";
require __DIR__ . '/vendor/autoload.php';

$REPO = $_SERVER['REPO'];
$PRID = $_SERVER['PRID'];
$AI_API_URL = $_SERVER['AI_API_URL'];
$AI_API_KEY = $_SERVER['AI_API_KEY'];
$APP_GITEA_TOKEN = $_SERVER['APP_GITEA_TOKEN'];
$APP_GITEA_URL = $_SERVER['APP_GITEA_URL']; // http://gitea-http:3000/api/v1/repos/:repo/issues/:prid/comments
$PATCH_DATA = $_SERVER['PATCH_DATA'];

if (!isset($REPO, $PRID, $AI_API_URL, $AI_API_KEY, $APP_GITEA_TOKEN, $APP_GITEA_URL, $PATCH_DATA)) {
    echo "Required environment variable missing.";
    exit(1); // Exit with an error status
}

echo $REPO;
echo $PRID;
echo $AI_API_URL;
echo $AI_API_KEY;
echo $APP_GITEA_TOKEN;
echo $APP_GITEA_URL;
echo $PATCH_DATA;

$APP_GITEA_URL = strtr($APP_GITEA_URL, [
    ':repo' => $REPO,
    ':prid' => $PRID,
]);

use ptlis\DiffParser\Parser;
$parser = new Parser();
$client = new \GuzzleHttp\Client();
$patchData = base64_decode($PATCH_DATA);
$changeset = $parser->parse($patchData, Parser::VCS_GIT);

foreach ($changeset->files as $file) {

    $codeDiff = [];

    foreach ($file->hunks as $hunkIndex => $hunk) {
        $hunkContent = '';

        $lineInfo = "@@ -$hunk->originalStart,$hunk->originalCount +$hunk->newStart,$hunk->newCount @@" . PHP_EOL;

        $hunkContent .= $lineInfo;

        foreach ($hunk->lines as $line) {
            if ($line->operation == 'added') {
                $hunkContent .= '+';
            } elseif ($line->operation == 'removed') {
                $hunkContent .= '-';
            } else {
                $hunkContent .= ' ';
            }
            $hunkContent .= $line->content . PHP_EOL;
        }

        $codeDiff[] = [
            'id' => $hunkIndex + 1,
            'code_diff' => base64_encode($hunkContent),
        ];
    }

    $payload = [
        'data' => $codeDiff,
    ];

    try {
        $response = $client->request('POST', $AI_API_URL, [
            'headers' => [
                'Content-Type' => 'application/json',
                'ApiKey' => $AI_API_KEY,
            ],
            'json' => $payload,
        ]);
        if ($response->getStatusCode() != 200) {
            throw new Exception("Error processing API request: " . $response->getBody());
        }
    } catch (\GuzzleHttp\Exception\GuzzleException $e) {
        echo "HTTP Request failed: " . $e->getMessage();
        exit(2);
    }    

    $result = json_decode($response->getBody(), false);

    echo json_encode($result, JSON_PRETTY_PRINT);

    $response = $client->request('POST', $APP_GITEA_URL, [
        'headers' => [
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer $APP_GITEA_TOKEN",
        ],
        'json' => [
            'body' => $result->data,
        ],
    ]);
}
