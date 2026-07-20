const translations = {
  en: {
    nav_features: "Features",
    nav_support: "Support",
    nav_store: "App Store",
    lang_label: "Language",
    hero_badge: "AVAILABLE ON THE APP STORE",
    hero_title_1: "Remember",
    hero_title_2: "what matters.",
    hero_sub: "Flashcards that adapt to your memory — not the other way around.",
    hero_desc: "No account. No clutter. Just focused reviews, clear progress, and optional private iCloud sync.",
    cta_appstore: "Get FlashForge",
    cta_github: "View source",
    trust_1: "Adaptive SM-2 + FSRS",
    trust_2: "Offline-first",
    trust_3: "Private by default",
    preview_eyebrow: "TODAY",
    preview_title: "Today's review",
    preview_deck: "All decks",
    preview_state: "12 cards ready",
    preview_label: "REVIEW",
    preview_card_title: "What do you want to remember?",
    preview_card_note: "Focus on one idea. FlashForge handles the timing.",
    preview_action: "Reveal answer",
    preview_insights: "LAST 7 DAYS",
    preview_reviews: "reviews completed",
    features_label: "DESIGNED FOR DAILY RECALL",
    features_title: "A calmer way to learn for the long term.",
    features_sub: "Everything you need to build a reliable study habit. Nothing you do not.",
    f1_title: "Adaptive review timing",
    f1_desc: "SM-2 and FSRS work together to schedule each card around your actual memory.",
    f4_title: "Insights you can use",
    f4_desc: "See review activity, retention, streaks, card progress, and what is due next.",
    f6_title: "Your data stays yours",
    f6_desc: "Study without an account. Keep data on-device, use private iCloud sync, or export a backup.",
    flow_label: "A SIMPLE RHYTHM",
    flow_title: "Build once. Review at the right time.",
    flow_1_title: "Create",
    flow_1_desc: "Turn ideas, vocabulary, or notes into focused cards.",
    flow_2_title: "Review",
    flow_2_desc: "Rate your recall and let the scheduler adjust the next interval.",
    flow_3_title: "Retain",
    flow_3_desc: "Use clear trends to stay consistent without chasing a perfect streak.",
    support_label: "INDEPENDENTLY BUILT",
    support_title: "Support FlashForge",
    support_sub: "Your support helps fund thoughtful updates, maintenance, and long-term availability.",
    support_coffee_btn: "Buy me a coffee",
    copy_btn: "Copy",
    copy_done: "Copied to clipboard",
    copy_failed: "Copy failed",
    footer_rights: "© 2026 FlashForge. All rights reserved.",
    footer_contact: "Contact",
    footer_terms: "Terms",
    footer_privacy: "Privacy"
  },
  ko: {
    nav_features: "주요 기능",
    nav_support: "후원",
    nav_store: "App Store",
    lang_label: "언어",
    hero_badge: "APP STORE에서 이용 가능",
    hero_title_1: "중요한 것을",
    hero_title_2: "더 오래 기억하세요.",
    hero_sub: "사용자의 기억에 맞춰 복습 시점을 조정하는 플래시카드.",
    hero_desc: "계정도, 복잡함도 없습니다. 집중 복습과 명확한 분석, 선택적인 비공개 iCloud 동기화만 담았습니다.",
    cta_appstore: "FlashForge 받기",
    cta_github: "소스 보기",
    trust_1: "SM-2 + FSRS 적응형 복습",
    trust_2: "오프라인 우선",
    trust_3: "기본부터 비공개",
    preview_eyebrow: "TODAY",
    preview_title: "오늘의 복습",
    preview_deck: "모든 덱",
    preview_state: "복습 카드 12개",
    preview_label: "REVIEW",
    preview_card_title: "무엇을 오래 기억하고 싶나요?",
    preview_card_note: "하나의 아이디어에 집중하세요. 다음 복습 시점은 FlashForge가 계산합니다.",
    preview_action: "정답 보기",
    preview_insights: "최근 7일",
    preview_reviews: "완료한 복습",
    features_label: "매일의 기억을 위한 설계",
    features_title: "오래 배우기 위한 더 차분한 방법.",
    features_sub: "꾸준한 학습 습관에 필요한 기능만 담았습니다.",
    f1_title: "기억에 맞는 복습 시점",
    f1_desc: "SM-2와 FSRS가 함께 작동해 실제 기억 상태에 맞춰 카드별 복습 간격을 계산합니다.",
    f4_title: "쓸모 있는 학습 분석",
    f4_desc: "복습 활동, 기억 유지율, 연속 학습, 카드 진도와 다음 복습량을 확인하세요.",
    f6_title: "내 데이터는 나에게",
    f6_desc: "계정 없이 학습하고, 기기에 저장하며, 비공개 iCloud 동기화나 백업 파일을 선택할 수 있습니다.",
    flow_label: "단순한 학습 흐름",
    flow_title: "한 번 만들고, 필요한 순간에 복습하세요.",
    flow_1_title: "생성",
    flow_1_desc: "아이디어, 단어, 메모를 집중할 수 있는 카드로 만드세요.",
    flow_2_title: "복습",
    flow_2_desc: "기억 정도를 평가하면 스케줄러가 다음 복습 간격을 조정합니다.",
    flow_3_title: "유지",
    flow_3_desc: "완벽한 스트릭보다 명확한 추세를 보며 꾸준함을 유지하세요.",
    support_label: "독립적으로 개발",
    support_title: "FlashForge 후원",
    support_sub: "후원은 신중한 업데이트와 유지보수, 장기적인 서비스 지속에 사용됩니다.",
    support_coffee_btn: "커피로 후원하기",
    copy_btn: "복사",
    copy_done: "클립보드에 복사되었습니다",
    copy_failed: "복사하지 못했습니다",
    footer_rights: "© 2026 FlashForge. All rights reserved.",
    footer_contact: "문의",
    footer_terms: "이용약관",
    footer_privacy: "개인정보처리방침"
  }
};

const langSelect = document.getElementById("langSelect");
const toastEl = document.getElementById("toast");
let currentLang = "en";
let toastTimer = null;

function t(key) {
  return translations[currentLang]?.[key] ?? translations.en[key] ?? key;
}

function applyLanguage(lang) {
  currentLang = translations[lang] ? lang : "en";
  document.documentElement.lang = currentLang;

  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const key = element.getAttribute("data-i18n");
    const value = t(key);
    if (value) {
      element.textContent = value;
    }
  });

  if (langSelect) {
    langSelect.value = currentLang;
  }
  localStorage.setItem("flashforge_lang", currentLang);
}

function showToast(message) {
  if (!toastEl) {
    return;
  }

  toastEl.textContent = message;
  toastEl.classList.add("show");

  if (toastTimer) {
    clearTimeout(toastTimer);
  }

  toastTimer = setTimeout(() => {
    toastEl.classList.remove("show");
  }, 1800);
}

async function copyText(text) {
  if (navigator.clipboard && window.isSecureContext) {
    await navigator.clipboard.writeText(text);
    return;
  }

  const temp = document.createElement("textarea");
  temp.value = text;
  temp.setAttribute("readonly", "");
  temp.style.position = "absolute";
  temp.style.left = "-9999px";
  document.body.appendChild(temp);
  temp.select();
  document.execCommand("copy");
  document.body.removeChild(temp);
}

function setupCopyButtons() {
  document.querySelectorAll(".copy-btn").forEach((button) => {
    button.addEventListener("click", async () => {
      const targetId = button.getAttribute("data-copy-target");
      const target = targetId ? document.getElementById(targetId) : null;
      if (!target) {
        return;
      }

      try {
        await copyText(target.textContent.trim());
        showToast(t("copy_done"));
      } catch (error) {
        showToast(t("copy_failed"));
      }
    });
  });
}

function setupLanguageSelector() {
  if (!langSelect) {
    return;
  }

  langSelect.addEventListener("change", (event) => {
    applyLanguage(event.target.value);
  });

  const saved = localStorage.getItem("flashforge_lang");
  const browser = navigator.language?.split("-")[0] ?? "en";
  const initialLang = saved || (translations[browser] ? browser : "en");
  applyLanguage(initialLang);
}

setupLanguageSelector();
setupCopyButtons();
