/**
 * SEO-friendly language detection and redirection
 * Since GitHub Pages doesn't support server-side redirects, 
 * we use JavaScript as a fallback
 */

(function() {
    // Only run on the main index.html page
    if (window.location.pathname !== '/' && window.location.pathname !== '/index.html') {
        return;
    }
    
    // Check URL parameters first
    const urlParams = new URLSearchParams(window.location.search);
    const langParam = urlParams.get('lang');
    const clearParam = urlParams.get('clear');
    
    // Clear language preference if requested
    if (clearParam === '1' || clearParam === 'true') {
        localStorage.removeItem('language');
        // Remove the clear parameter from URL
        urlParams.delete('clear');
        const newUrl = window.location.pathname + (urlParams.toString() ? '?' + urlParams.toString() : '');
        window.history.replaceState({}, '', newUrl);
        return;
    }
    
    // If user explicitly navigated to index.html, respect that choice
    const referrer = document.referrer;
    if (referrer && referrer.includes('index-en.html')) {
        localStorage.setItem('language', 'ja');
        return;
    }
    
    // Check if we should redirect to English version
    const browserLang = navigator.language || navigator.userLanguage;
    const savedLang = localStorage.getItem('language');
    
    // Priority: URL parameter > saved preference > browser language
    let targetLang = 'ja'; // default
    
    if (langParam && ['en', 'ja'].includes(langParam)) {
        targetLang = langParam;
        localStorage.setItem('language', langParam);
    } else if (savedLang && ['en', 'ja'].includes(savedLang)) {
        targetLang = savedLang;
    } else if (browserLang && browserLang.toLowerCase().startsWith('en') && !savedLang) {
        // Only use browser language if no preference is saved
        targetLang = 'en';
    }
    
    // Redirect to English version if needed
    if (targetLang === 'en' && !langParam) {
        // Save the preference
        localStorage.setItem('language', 'en');
        
        // Redirect to English version
        window.location.href = 'index-en.html';
    } else if (targetLang === 'ja') {
        // Save Japanese preference
        localStorage.setItem('language', 'ja');
    }
})();