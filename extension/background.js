// XYZ Player Extension - Background Service Worker

// 1. Ağ akışlarını (m3u8 ve mp4) yakala ve oturum hafızasına kaydet
chrome.webRequest.onBeforeRequest.addListener(
  (details) => {
    if (details.tabId > 0 && details.url) {
      const u = details.url.toLowerCase();
      // Reklam ve analytics dışındaki video akışlarını yakala
      if (u.includes(".m3u8") || u.includes(".mp4")) {
        chrome.storage.session.set({
          [`tab_${details.tabId}`]: {
            streamUrl: details.url,
            initiator: details.initiator || details.documentUrl || "",
            time: Date.now()
          }
        });

        // Simgeye yeşil READY rozeti koy
        chrome.action.setBadgeText({ tabId: details.tabId, text: "READY" });
        chrome.action.setBadgeBackgroundColor({ tabId: details.tabId, color: "#10b981" });
      }
    }
  },
  { urls: ["*://*/*.m3u8*", "*://*/*.mp4*"] }
);

// Sekme kapandığında hafızayı temizle
chrome.tabs.onRemoved.addListener((tabId) => {
  chrome.storage.session.remove(`tab_${tabId}`);
});

// 2. Eklenti butonuna tıklandığında oynatıcıyı tetikle
chrome.action.onClicked.addListener(async (tab) => {
  if (!tab.id || !tab.url) return;

  const key = `tab_${tab.id}`;
  const data = await chrome.storage.session.get([key]);
  const streamData = data[key];

  let targetUrl = streamData ? streamData.streamUrl : null;
  let referer = (streamData && streamData.initiator) ? streamData.initiator : tab.url;

  // Ağdan yakalanmadıysa tüm frame'lerdeki (iframe dahil) video etiketlerini tara
  if (!targetUrl) {
    try {
      const results = await chrome.scripting.executeScript({
        target: { tabId: tab.id, allFrames: true },
        func: () => {
          const video = document.querySelector("video");
          if (video) {
            const src = video.currentSrc || video.src;
            if (src && !src.startsWith("blob:")) {
              return src;
            }
          }
          const source = document.querySelector("video source");
          if (source && source.src) {
            return source.src;
          }
          return null;
        }
      });

      if (results && results.length > 0) {
        for (const frame of results) {
          if (frame.result) {
            targetUrl = frame.result;
            break;
          }
        }
      }
    } catch (e) {
      console.warn("Frame sorgusu hatası:", e);
    }
  }

  // Son çare: YouTube vb. siteler için doğrudan sayfa URL'si
  if (!targetUrl) {
    targetUrl = tab.url;
  }

  // Standart ve temiz URL yapısı: xyz://open?url=...&ref=...&title=...
  const pageTitle = tab.title ? tab.title.replace(/\s*[-|]\s*OpenAnime.*$/i, "").trim() : "";
  const launchUrl = `xyz://open?url=${encodeURIComponent(targetUrl)}&ref=${encodeURIComponent(referer)}&title=${encodeURIComponent(pageTitle)}`;

  try {
    await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: (url) => {
        // Mevcut sayfadaki videoları duraklat
        document.querySelectorAll("video").forEach((v) => v.pause());

        // Görünmez link üzerinden tetikle
        const link = document.createElement("a");
        link.href = url;
        link.style.display = "none";
        document.body.appendChild(link);
        link.click();
        link.remove();
      },
      args: [launchUrl]
    });

    chrome.action.setBadgeText({ tabId: tab.id, text: "PLAY" });
    chrome.action.setBadgeBackgroundColor({ tabId: tab.id, color: "#3b82f6" });
    setTimeout(() => {
      chrome.action.setBadgeText({ tabId: tab.id, text: "" });
    }, 4000);
  } catch (err) {
    console.error("Protokol başlatılamadı:", err);
  }
});
