#!/usr/bin/env node
// upload-image-to-github.mjs — GitHub PR コメント欄経由で画像をアップロードし URL を取得
//
// Usage: node scripts/upload-image-to-github.mjs <PR_URL> <IMAGE_PATH> [<IMAGE_PATH>...]
//
// 出力: 各画像の user-attachments URL（1行1URL）
//
// 前提:
//   - @playwright/cli がグローバルインストール済み
//   - GitHub セッション認証済み:
//     npx @playwright/cli -s=github open --headed "https://github.com/login"
//     (ログイン後)
//     npx @playwright/cli -s=github state-save ~/.playwright-github-session/state.json

// playwright をグローバル or @playwright/cli の依存から動的に解決
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  const globalModules = require('child_process')
    .execSync('npm root -g', { encoding: 'utf8' }).trim();
  ({ chromium } = require(`${globalModules}/playwright`));
}
import { homedir } from 'os';
import { resolve, join } from 'path';
import { existsSync } from 'fs';

const args = process.argv.slice(2);
if (args.length < 2) {
  console.error('Usage: node upload-image-to-github.mjs <PR_URL> <IMAGE_PATH> [<IMAGE_PATH>...]');
  process.exit(1);
}

const prUrl = args[0];
const imagePaths = args.slice(1).map(p => resolve(p));

// 認証状態ファイル
const stateFile = join(homedir(), '.playwright-github-session', 'state.json');
if (!existsSync(stateFile)) {
  console.error(`認証状態ファイルが見つかりません: ${stateFile}`);
  console.error('以下を実行して認証してください:');
  console.error('  npx @playwright/cli -s=github open --headed "https://github.com/login"');
  console.error('  npx @playwright/cli -s=github state-save ~/.playwright-github-session/state.json');
  process.exit(1);
}

// ブラウザ起動（認証状態を読み込み）
const browser = await chromium.launch({
  headless: true,
  channel: 'chrome',
});

const context = await browser.newContext({
  storageState: stateFile,
});

try {
  const page = await context.newPage();

  for (const imagePath of imagePaths) {
    // ページを再読み込みしてクリーンな状態にする
    await page.goto(prUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
    const ta = page.locator('textarea#new_comment_field');
    await ta.waitFor({ state: 'visible', timeout: 15000 });
    await ta.click();

    // GitHub のドラフト復元で古い URL が残ることがあるため textarea をクリア
    await ta.fill('');
    // fill 後の値が反映されるのを確認
    await page.waitForFunction(() => {
      const el = document.querySelector('textarea#new_comment_field');
      return el && el.value === '';
    }, { timeout: 5000 });

    // file-attachment の input[type=file] に画像をセット
    const fileInput = page.locator('file-attachment input[type="file"]').first();
    await fileInput.setInputFiles(imagePath);

    // アップロード完了を待つ（textarea に URL が入るまで）
    try {
      await page.waitForFunction(() => {
        const el = document.querySelector('textarea#new_comment_field');
        return el && el.value.includes('user-attachments/assets/');
      }, { timeout: 30000 });

      const value = await ta.inputValue();
      const match = value.match(/https:\/\/github\.com\/user-attachments\/assets\/[\w-]+/);
      if (match) {
        console.log(match[0]);
      } else {
        console.log('UPLOAD_FAILED');
      }
    } catch {
      console.log('UPLOAD_FAILED');
    }
  }
} finally {
  await context.close();
  await browser.close();
}
