document.addEventListener('DOMContentLoaded', () => {
  const app = document.getElementById('app');

  fetch('/../Concours de poésis-form.html')
    .then(response => response.text())
    .then(html => {
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, 'text/html');

      const bodyContent = doc.body.innerHTML;
      const headStyle = doc.querySelector('style');

      if (headStyle) {
        const style = document.createElement('style');
        style.textContent = headStyle.textContent;
        document.head.appendChild(style);
      }

      app.innerHTML = bodyContent;

      const scripts = doc.querySelectorAll('script');
      scripts.forEach(script => {
        if (script.textContent) {
          const newScript = document.createElement('script');
          newScript.textContent = script.textContent;
          document.body.appendChild(newScript);
        }
      });
    })
    .catch(err => console.error('Erreur lors du chargement du formulaire:', err));
});
