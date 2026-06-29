import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import satori from 'satori';
import { html } from 'satori-html';
import { Resvg } from '@resvg/resvg-js';

// Cache fonts in memory
let robotoRegular: ArrayBuffer | null = null;
let robotoBold: ArrayBuffer | null = null;

async function loadFonts() {
  if (!robotoRegular) {
    const res = await fetch('https://fonts.gstatic.com/s/roboto/v30/KFOmCnqEu92Fr1Me5Q.ttf');
    robotoRegular = await res.arrayBuffer();
  }
  if (!robotoBold) {
    const res = await fetch('https://fonts.gstatic.com/s/roboto/v30/KFOlCnqEu92Fr1MmWUlvAw.ttf');
    robotoBold = await res.arrayBuffer();
  }
}

const FORMAT_DIMENSIONS: Record<string, { width: number; height: number }> = {
  'instagram_feed': { width: 1080, height: 1080 },
  'instagram_story': { width: 1080, height: 1920 },
  'facebook': { width: 1200, height: 630 },
  'twitter': { width: 1600, height: 900 },
  'linkedin': { width: 1200, height: 627 },
  'whatsapp': { width: 1080, height: 1350 },
  'high_res': { width: 2160, height: 2160 },
};

function getTemplateHtml(post: any, dims: { width: number, height: number }) {
  const isBirthday = post.type === 'birthday';
  
  // AppClub primary colors
  const bgColor = isBirthday ? '#FFFAF0' : '#F8FAFC'; // Lighter bg
  const primaryColor = '#10B981'; // emerald-500
  const accentColor = '#3B82F6'; // blue-500
  const textColor = '#0F172A'; // slate-900

  // Optional background image pattern or solid
  let bgStyle = `display: flex; flex-direction: column; width: 100%; height: 100%; background-color: ${bgColor}; padding: 80px; justify-content: space-between;`;

  // We can use emojis instead of complex SVGs for now
  const headerIcon = isBirthday ? '🎉' : '🏆';

  let dateStr = 'Reciente';
  try {
    if (post.createdAt) {
      if (post.createdAt.toDate) {
        dateStr = post.createdAt.toDate().toLocaleDateString('es-AR');
      } else if (typeof post.createdAt === 'string') {
        dateStr = new Date(post.createdAt).toLocaleDateString('es-AR');
      } else if (typeof post.createdAt === 'number') {
        dateStr = new Date(post.createdAt).toLocaleDateString('es-AR');
      } else if (post.createdAt._seconds) {
        dateStr = new Date(post.createdAt._seconds * 1000).toLocaleDateString('es-AR');
      }
    }
  } catch(e) {}

  // Build HTML string
  // Note: Satori requires flexbox for almost all layout
  return html`
    <div style="${bgStyle} font-family: 'Roboto', sans-serif;">
      <!-- Header -->
      <div style="display: flex; flex-direction: row; justify-content: space-between; align-items: center; width: 100%;">
        <div style="display: flex; align-items: center;">
          <div style="display: flex; justify-content: center; align-items: center; width: 100px; height: 100px; background-color: ${primaryColor}; border-radius: 24px; color: white; font-size: 48px; font-weight: bold; margin-right: 30px;">
            AC
          </div>
          <div style="display: flex; flex-direction: column;">
            <span style="font-size: 42px; font-weight: bold; color: ${textColor};">AppClub</span>
            <span style="font-size: 28px; color: #64748B;">Comunidad Deportiva</span>
          </div>
        </div>
        <div style="display: flex; font-size: 32px; color: #64748B;">
          ${dateStr}
        </div>
      </div>

      <!-- Main Content -->
      <div style="display: flex; flex-direction: column; flex-grow: 1; justify-content: center; align-items: center; text-align: center; margin: 60px 0;">
        ${isBirthday ? `<div style="font-size: 140px; margin-bottom: 40px;">${headerIcon} 🎈</div>` : ''}
        
        <div style="font-size: 64px; font-weight: bold; color: ${isBirthday ? accentColor : textColor}; margin-bottom: 40px; line-height: 1.2;">
          ${post.title}
        </div>
        
        <div style="font-size: 42px; color: #334155; line-height: 1.5; text-align: center; max-width: 90%;">
          ${post.body}
        </div>

        ${post.imageUrl ? `<img src="${post.imageUrl}" style="margin-top: 60px; max-height: 400px; border-radius: 24px; object-fit: cover;" />` : ''}
      </div>

      <!-- Footer -->
      <div style="display: flex; flex-direction: row; justify-content: space-between; align-items: center; width: 100%; border-top: 4px solid #E2E8F0; padding-top: 40px;">
        <span style="font-size: 32px; color: #64748B; font-weight: bold;">www.appclub.com</span>
        <div style="display: flex; align-items: center;">
          <span style="font-size: 32px; color: ${primaryColor}; font-weight: bold;">@appclub_ok</span>
        </div>
      </div>
    </div>
  `;
}

export const exportPostImage = functions.https.onCall(async (data, context) => {
  // 1. Verify Authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado.');
  }

  const { postId, format = 'instagram_feed' } = data;

  if (!postId) {
    throw new functions.https.HttpsError('invalid-argument', 'El postId es requerido.');
  }

  const dims = FORMAT_DIMENSIONS[format] || FORMAT_DIMENSIONS['instagram_feed'];

  try {
    // 2. Fetch the post from Firestore
    const db = admin.firestore();
    const doc = await db.collection('novedades').doc(postId).get();
    
    if (!doc.exists) {
      throw new functions.https.HttpsError('not-found', 'La publicación no existe.');
    }

    const postData = doc.data();

    // 3. Ensure fonts are loaded
    await loadFonts();

    // 4. Generate HTML Template
    const template = getTemplateHtml(postData, dims);

    // 5. Convert HTML to SVG via Satori
    const svg = await satori(template as any, {
      width: dims.width,
      height: dims.height,
      fonts: [
        { name: 'Roboto', data: robotoRegular!, weight: 400, style: 'normal' },
        { name: 'Roboto', data: robotoBold!, weight: 700, style: 'normal' }
      ],
    });

    // 6. Rasterize SVG to PNG via resvg-js
    const resvg = new Resvg(svg, {
      background: 'rgba(255, 255, 255, 1)',
      fitTo: { mode: 'original' }
    });

    const pngData = resvg.render();
    const pngBuffer = pngData.asPng();

    // 7. Return base64 to client
    return {
      success: true,
      base64Image: pngBuffer.toString('base64'),
      format,
      width: dims.width,
      height: dims.height
    };
  } catch (error: any) {
    console.error('Error generating image:', error);
    throw new functions.https.HttpsError('internal', 'Error interno al generar la imagen', error.message);
  }
});
