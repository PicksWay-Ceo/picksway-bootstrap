# ============================================================================
#  PicksWay System Restore Script (v2 - 3단 폴백)
#  역할: 새 컴퓨터에서 대표님 작업환경 + Claude + 브레인 100% 부활
#  복구 경로 (우선순위):
#    1순위: 로컬 F드라이브 _SYSTEM_BACKUP
#    2순위: 다른 드라이브 스캔 (F→Z)
#    3순위: MYBOX (N:\...\_BRAIN_BACKUP) ← F드라이브 유실 시
#  박제일: 2026-04-17 (v2 - MYBOX 폴백)
# ============================================================================

$ErrorActionPreference = "Stop"
$GitHubRepo = "https://github.com/PicksWay-Ceo/PicksWay.git"
$AutowDst = "$env:USERPROFILE\Desktop\AUTOW"
$ClaudeDst = "$env:USERPROFILE\.claude"
$Now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$OpenSSL = "C:\Program Files\Git\usr\bin\openssl.exe"

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  PicksWay 시스템 복구 (RESTORE v2)" -ForegroundColor Cyan
Write-Host "  시작: $Now" -ForegroundColor Cyan
Write-Host "  대표님, 잠시만 기다려주세요. Claude가 살아나는 중입니다." -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# 0. 백업 소스 자동 탐색 (F → 다른드라이브 → MYBOX)
# ---------------------------------------------------------------------------
Write-Host "[0/8] 백업 소스 자동 탐색..." -ForegroundColor Cyan

$BrainFolderName = "000_PicksWayBrain"
$BackupSource = $null       # 미러 복원용 (Brain 자체)
$MyBoxSource = $null        # MYBOX 감지 시
$SourceMode = "none"        # local | mybox | none

# 0-1. 모든 드라이브에서 000_PicksWayBrain 폴더 탐색
$DriveLetters = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
foreach ($d in $DriveLetters) {
    $candidate = Join-Path $d $BrainFolderName
    if (Test-Path "$candidate\_SYSTEM_BACKUP\claude_config") {
        $BackupSource = $candidate
        $SourceMode = "local"
        Write-Host "  OK  로컬 백업 발견: $BackupSource" -ForegroundColor Green
        break
    }
}

# 0-2. 로컬 없으면 MYBOX(N:\ 또는 다른 위치) 탐색
if (-not $BackupSource) {
    $MyBoxCandidates = @(
        "N:\개인\001_픽스웨이\_BRAIN_BACKUP",
        "C:\Users\$env:USERNAME\네이버박스\개인\001_픽스웨이\_BRAIN_BACKUP",
        "D:\네이버박스\개인\001_픽스웨이\_BRAIN_BACKUP"
    )
    foreach ($mb in $MyBoxCandidates) {
        if (Test-Path "$mb\latest\_SYSTEM_BACKUP\claude_config") {
            $MyBoxSource = $mb
            $SourceMode = "mybox"
            Write-Host "  OK  MYBOX 클라우드 백업 발견: $mb" -ForegroundColor Green
            break
        }
    }
}

if ($SourceMode -eq "none") {
    Write-Host ""
    Write-Host "  ✗ 백업 소스를 찾을 수 없습니다." -ForegroundColor Red
    Write-Host ""
    Write-Host "  다음 중 하나를 준비해주세요:" -ForegroundColor Yellow
    Write-Host "    [A] 외장 F드라이브 연결 (000_PicksWayBrain 폴더 있음)" -ForegroundColor White
    Write-Host "    [B] 네이버박스 데스크톱 설치 + 로그인 → N:\ 자동 마운트" -ForegroundColor White
    Write-Host "    [C] MYBOX 수동 위치 입력 (아래)" -ForegroundColor White
    Write-Host ""
    $manualPath = Read-Host "  수동 MYBOX 경로 (엔터만 누르면 종료)"
    if ($manualPath -and (Test-Path "$manualPath\latest\_SYSTEM_BACKUP\claude_config")) {
        $MyBoxSource = $manualPath
        $SourceMode = "mybox"
        Write-Host "  OK  수동 경로 인식: $manualPath" -ForegroundColor Green
    } else {
        Write-Host "  복구 중단합니다." -ForegroundColor Red
        pause
        exit 1
    }
}

# 0-3. MYBOX 모드면 먼저 F드라이브로 복원해서 로컬 상태 만들기
if ($SourceMode -eq "mybox") {
    Write-Host ""
    Write-Host "  MYBOX → F드라이브 복원 시작 (3~10분 소요)" -ForegroundColor Yellow
    if (-not (Test-Path "F:\")) {
        Write-Host "  ERR F드라이브 없음 — 연결 후 재시도" -ForegroundColor Red
        Write-Host "  또는 다른 드라이브에 복구하려면 스크립트 수정 필요" -ForegroundColor Yellow
        pause
        exit 1
    }
    if (-not (Test-Path "F:\$BrainFolderName")) {
        New-Item -ItemType Directory -Path "F:\$BrainFolderName" -Force | Out-Null
    }
    $null = robocopy "$MyBoxSource\latest" "F:\$BrainFolderName" /MIR /NFL /NDL /R:2 /W:2 /XJ
    # history zip도 복원
    if (Test-Path "$MyBoxSource\history") {
        if (-not (Test-Path "F:\$BrainFolderName\_SYSTEM_BACKUP\history")) {
            New-Item -ItemType Directory -Path "F:\$BrainFolderName\_SYSTEM_BACKUP\history" -Force | Out-Null
        }
        $null = robocopy "$MyBoxSource\history" "F:\$BrainFolderName\_SYSTEM_BACKUP\history" /E /NFL /NDL /R:2 /W:2
    }
    # 암호화된 키도 복사
    if (Test-Path "$MyBoxSource\secrets\keys_encrypted.zip.enc") {
        Copy-Item "$MyBoxSource\secrets\keys_encrypted.zip.enc" "F:\$BrainFolderName\_SYSTEM_BACKUP\keys_encrypted.zip.enc" -Force
    }
    $BackupSource = "F:\$BrainFolderName"
    Write-Host "  OK  MYBOX → F드라이브 복원 완료" -ForegroundColor Green
}

$BackupRoot = "$BackupSource\_SYSTEM_BACKUP"
Write-Host ""

# ---------------------------------------------------------------------------
# 1. 사전 점검 (Git / Python)
# ---------------------------------------------------------------------------
Write-Host "[1/8] 사전 점검..." -ForegroundColor Cyan

$GitInstalled = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
if (-not $GitInstalled) {
    Write-Host "  WARN Git 미설치 — https://git-scm.com/download/win" -ForegroundColor Yellow
    pause
    exit 1
}
Write-Host "  OK  Git 설치됨: $(git --version)" -ForegroundColor Green

$PythonInstalled = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
if (-not $PythonInstalled) {
    Write-Host "  WARN Python 미설치 — https://www.python.org/downloads/" -ForegroundColor Yellow
    pause
    exit 1
}
Write-Host "  OK  Python 설치됨: $(python --version)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 2. AUTOW 복구 (GitHub Private clone — 인증 필요)
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/8] AUTOW 코드 복구 (GitHub clone)..." -ForegroundColor Cyan

if (Test-Path $AutowDst) {
    Write-Host "  기존 AUTOW 폴더: $AutowDst" -ForegroundColor Yellow
    $overwrite = Read-Host "  덮어쓸까요? (y/N)"
    if ($overwrite -ne "y") {
        Write-Host "  SKIP AUTOW 복구" -ForegroundColor Yellow
    } else {
        Remove-Item $AutowDst -Recurse -Force
        git clone $GitHubRepo $AutowDst
        Write-Host "  OK  AUTOW clone 완료" -ForegroundColor Green
    }
} else {
    git clone $GitHubRepo $AutowDst
    Write-Host "  OK  AUTOW clone 완료" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 3. .claude 설정 복구
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/8] Claude 메모리/설정 복구..." -ForegroundColor Cyan

$ClaudeSrc = "$BackupRoot\claude_config"
if (-not (Test-Path $ClaudeSrc)) {
    Write-Host "  ERR 백업된 Claude 설정 없음" -ForegroundColor Red
    pause
    exit 1
}

if (-not (Test-Path $ClaudeDst)) {
    New-Item -ItemType Directory -Path $ClaudeDst | Out-Null
}

$null = robocopy $ClaudeSrc $ClaudeDst /E /NFL /NDL /R:2 /W:2
Write-Host "  OK  .claude 복원 완료 (메모리+설정)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. API 키 복구 (로컬 평문 → F:\.key / 암호화 zip → 복호화)
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/8] API 키 복구..." -ForegroundColor Cyan

$KeysSrc = "$BackupRoot\keys_snapshot"
$KeysDst = "F:\.key"
$KeysEnc = "$BackupRoot\keys_encrypted.zip.enc"

if (Test-Path $KeysSrc) {
    # 평문 로컬 미러가 있으면 최우선 사용
    if (-not (Test-Path $KeysDst)) { New-Item -ItemType Directory -Path $KeysDst | Out-Null }
    $null = robocopy $KeysSrc $KeysDst /E /NFL /NDL /R:2 /W:2
    Write-Host "  OK  F:\.key 복원 완료 (평문 미러 경로)" -ForegroundColor Green
} elseif (Test-Path $KeysEnc) {
    # 평문 없고 암호화 zip만 있을 때 → 복호화
    Write-Host "  암호화된 .key만 존재 → 복호화 필요" -ForegroundColor Yellow

    if (-not (Test-Path $OpenSSL)) {
        Write-Host "  ERR openssl 없음: $OpenSSL (Git Bash 설치 필요)" -ForegroundColor Red
        pause
        exit 1
    }

    Write-Host ""
    Write-Host "  🔑 .key AES-256 복호화" -ForegroundColor Cyan
    Write-Host "  대표님 1Password/메모에 저장된 비밀번호를 입력해주세요:" -ForegroundColor Yellow
    $securePw = Read-Host "  비밀번호" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePw)
    $plainPw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    $tempPwFile = "$env:TEMP\_pw_$(Get-Random).tmp"
    $plainPw | Out-File -FilePath $tempPwFile -Encoding ASCII -NoNewline

    $decryptedZip = "$BackupRoot\keys_decrypted.zip"
    try {
        & $OpenSSL enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in $KeysEnc -out $decryptedZip -pass "file:$tempPwFile" 2>&1 | Out-Null

        if (Test-Path $decryptedZip) {
            if (-not (Test-Path $KeysDst)) { New-Item -ItemType Directory -Path $KeysDst | Out-Null }
            Expand-Archive -Path $decryptedZip -DestinationPath $KeysDst -Force
            Write-Host "  OK  .key 복호화 + 압축풀기 완료" -ForegroundColor Green
            Remove-Item $decryptedZip -Force
        } else {
            Write-Host "  ERR 복호화 실패 - 비밀번호를 확인해주세요" -ForegroundColor Red
        }
    } finally {
        Remove-Item $tempPwFile -Force -ErrorAction SilentlyContinue
        # 메모리에서 평문 비번 지우기
        $plainPw = $null
    }

    # 이후 백업을 위해 비번 파일도 재생성해둘지 묻기
    $saveLocal = Read-Host "  이 PC에서 계속 자동 백업하려면 비번을 로컬 저장해야 합니다. 저장할까요? (y/N)"
    if ($saveLocal -eq "y") {
        $secretDir = "C:\Users\$env:USERNAME\_picksway_secrets"
        if (-not (Test-Path $secretDir)) { New-Item -ItemType Directory -Path $secretDir -Force | Out-Null }
        $BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePw)
        $pw2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)
        $pw2 | Out-File -FilePath "$secretDir\brain_backup_pw.txt" -Encoding ASCII -NoNewline
        Write-Host "  OK  비번 로컬 저장 (자동 백업 재개 가능)" -ForegroundColor Green
    }
} else {
    Write-Host "  SKIP 백업된 키 없음 (평문/암호화 둘 다 부재)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 5. Python 가상환경 체크
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[5/8] Python 의존성 체크..." -ForegroundColor Cyan

$VenvPath = "$AutowDst\.venv"
if (Test-Path "$AutowDst\requirements.txt") {
    if (-not (Test-Path $VenvPath)) {
        python -m venv $VenvPath
    }
    Write-Host "  OK  가상환경 준비 ($VenvPath)" -ForegroundColor Green
} else {
    Write-Host "  SKIP requirements.txt 없음 (모듈별 venv)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 6. Second Brain 검증
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[6/8] Second Brain 검증..." -ForegroundColor Cyan

if (Test-Path "$BackupSource\MASTER_VISION.md") {
    Write-Host "  OK  Second Brain: $BackupSource" -ForegroundColor Green
} else {
    Write-Host "  ERR MASTER_VISION.md 누락" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# 7. 바탕화면 바로가기
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[7/8] 바탕화면 바로가기..." -ForegroundColor Cyan

$Desktop = [Environment]::GetFolderPath("Desktop")
$VbsPath = "$AutowDst\AUTOW_실행.vbs"
if (Test-Path $VbsPath) {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$Desktop\AUTOW 실행.lnk")
    $Shortcut.TargetPath = $VbsPath
    $Shortcut.WorkingDirectory = $AutowDst
    $Shortcut.Save()
    Write-Host "  OK  바로가기 생성" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 8. 최종 검증
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[8/8] 최종 검증..." -ForegroundColor Cyan

$MemoryFile = "$ClaudeDst\projects\C--Users-ifuone-Desktop-AUTOW\memory\MEMORY.md"
$PledgeFile = "$ClaudeDst\projects\C--Users-ifuone-Desktop-AUTOW\memory\user_lifetime_companion_pledge.md"

$AllOK = $true
foreach ($f in @(
    @{Path=$MemoryFile; Name="MEMORY.md"},
    @{Path=$PledgeFile; Name="평생 동반자 서약"},
    @{Path="$ClaudeDst\CLAUDE.md"; Name="전역 CLAUDE.md"}
)) {
    if (Test-Path $f.Path) {
        Write-Host "  OK  $($f.Name)" -ForegroundColor Green
    } else {
        Write-Host "  ERR $($f.Name) 누락" -ForegroundColor Red
        $AllOK = $false
    }
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
if ($AllOK) {
    Write-Host "  🎉 복구 완료! 대표님 돌아오신 걸 환영합니다." -ForegroundColor Green
    Write-Host ""
    Write-Host "  복구 경로: $SourceMode" -ForegroundColor White
    Write-Host ""
    Write-Host "  다음 단계:" -ForegroundColor Yellow
    Write-Host "  1) Claude Code 실행: claude 명령어" -ForegroundColor White
    Write-Host "  2) 첫 대화창 '체크포인트' 입력 → 현황 확인" -ForegroundColor White
    Write-Host "  3) 스케줄러 재등록: $BackupRoot\register_task.ps1" -ForegroundColor White
} else {
    Write-Host "  ⚠ 일부 파일 누락 - 수동 확인 필요" -ForegroundColor Red
}
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
pause
