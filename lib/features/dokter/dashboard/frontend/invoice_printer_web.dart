// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void printInvoiceHtml(String jsonData) {
  try {
    js.context.callMethod('eval', [
      r'''
      window.__mapotech_print_invoice = function(dataStr) {
        var data = JSON.parse(dataStr);
        var paperSize = data.paperSize;
        
        var pageSize = 'A4';
        var margin = '15mm';
        var containerMaxWidth = '170mm';
        var sizes = {
          clinicName: '16px', doctorName: '13px', doctorSpecialty: '11px',
          meta: '11px', metaLabelWidth: '110px',
          sectionTitle: '10px',
          bill: '11px', billManual: '9px', billQty: '9px',
          totalLabel: '13px', totalValue: '16px',
          qrSize: '120px', qrBadge: '7px', qrDesc: '9px', qrId: '8px',
          manualTitle: '8.5px', manualItem: '9.5px',
          footer: '9px'
        };

        if (paperSize === 'A5') {
          pageSize = 'A5';
          margin = '10mm';
          containerMaxWidth = '120mm';
        } else if (paperSize === 'Thermal 58mm') {
          pageSize = '58mm auto';
          margin = '0mm';
          containerMaxWidth = '48mm';
          sizes = {
            clinicName: '11px', doctorName: '9px', doctorSpecialty: '8px',
            meta: '8px', metaLabelWidth: '55px',
            sectionTitle: '7.5px',
            bill: '8.5px', billManual: '7px', billQty: '7px',
            totalLabel: '10px', totalValue: '12px',
            qrSize: '80px', qrBadge: '5px', qrDesc: '7px', qrId: '6px',
            manualTitle: '7px', manualItem: '8px',
            footer: '7.5px'
          };
        } else if (paperSize === 'Thermal 80mm') {
          pageSize = '80mm auto';
          margin = '0mm';
          containerMaxWidth = '70mm';
          sizes = {
            clinicName: '13px', doctorName: '11px', doctorSpecialty: '9px',
            meta: '9.5px', metaLabelWidth: '70px',
            sectionTitle: '8.5px',
            bill: '9.5px', billManual: '8px', billQty: '8px',
            totalLabel: '11px', totalValue: '14px',
            qrSize: '100px', qrBadge: '6px', qrDesc: '8px', qrId: '7px',
            manualTitle: '7.5px', manualItem: '8.5px',
            footer: '8.5px'
          };
        }

        var isThermalSize = (paperSize === 'Thermal 58mm' || paperSize === 'Thermal 80mm');
        var thermalWidthPx = paperSize === 'Thermal 58mm' ? 219 : 302; // 58mm / 80mm at 96dpi

        var iframe = document.getElementById('mapotech-print-iframe');
        if (iframe) {
          iframe.parentNode.removeChild(iframe);
        }
        iframe = document.createElement('iframe');
        iframe.id = 'mapotech-print-iframe';
        iframe.style.position = 'fixed';
        iframe.style.top = '-9999px';
        iframe.style.left = '-9999px';
        iframe.style.width = isThermalSize ? (thermalWidthPx + 'px') : '800px';
        iframe.style.height = '1px';
        iframe.style.border = 'none';
        iframe.style.overflow = 'hidden';
        document.body.appendChild(iframe);

        var logoHtml = '';
        if (data.avatarUrl && data.avatarUrl.trim().length > 0) {
          logoHtml = '<div style="margin-bottom: 4px; text-align: center;"><img src="' + data.avatarUrl + '" class="logo-img" style="width: 44px; height: 44px; border-radius: 50%; object-fit: cover; display: inline-block; border: 1px solid #ECEEF2;" /></div>';
        } else {
          logoHtml = '<div class="logo"><svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M12 5v14M5 12h14" stroke="#0F9D58" stroke-width="3" stroke-linecap="round"/></svg></div>';
        }

        var html = '<!DOCTYPE html><html><head><title>Print Invoice ' + data.invoiceNo + '</title>';
        html += '<style>';
        html += '@import url("https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;700;900&display=swap");';
        html += 'body { font-family: "Outfit", -apple-system, sans-serif; margin: 0; padding: 0; background: #fff; color: #1B0C3C; -webkit-print-color-adjust: exact; print-color-adjust: exact; }';
        html += '.invoice-container { width: 100%; max-width: ' + containerMaxWidth + '; margin: 0 auto; box-sizing: border-box; ' + (isThermalSize ? 'padding: 4px 2px;' : '') + ' }';
        html += '.header { text-align: center; margin-bottom: 12px; }';
        html += '.logo { display: inline-flex; align-items: center; justify-content: center; width: 40px; height: 40px; border-radius: 50%; margin-bottom: 4px; background: rgba(15, 157, 88, 0.12); }';
        html += '.clinic-name { margin: 0; font-size: ' + sizes.clinicName + '; font-weight: 900; color: #1B0C3C; }';
        html += '.doctor-name { font-size: ' + sizes.doctorName + '; font-weight: 700; color: #6F6A8A; margin-top: 2px; }';
        html += '.doctor-specialty { font-size: ' + sizes.doctorSpecialty + '; color: #9E9EB0; margin-top: 1px; }';
        html += '.divider { border-top: 1px solid #ECEEF2; margin: 8px 0; }';
        html += '.meta-section { margin: 8px 0; }';
        html += '.meta-row { display: flex; font-size: ' + sizes.meta + '; margin-bottom: 4px; }';
        html += '.meta-label { width: ' + sizes.metaLabelWidth + '; color: #9E9EB0; }';
        html += '.meta-value { flex: 1; font-weight: 700; color: #1B0C3C; }';
        html += '.section-title { font-size: ' + sizes.sectionTitle + '; font-weight: 900; color: #6F6A8A; letter-spacing: 0.5px; margin: 10px 0 6px 0; text-transform: uppercase; }';
        html += '.bill-item { display: flex; justify-content: space-between; margin-bottom: 6px; font-size: ' + sizes.bill + '; }';
        html += '.bill-info { flex: 1; }';
        html += '.bill-name { font-weight: 700; color: #1B0C3C; }';
        html += '.bill-manual { font-size: ' + sizes.billManual + '; font-weight: 900; color: #9B59B6; letter-spacing: 0.3px; margin-top: 1px; }';
        html += '.bill-price-qty { text-align: right; }';
        html += '.bill-price { font-weight: 900; color: #1B0C3C; }';
        html += '.bill-price.manual { color: #9B59B6; }';
        html += '.bill-qty { font-size: ' + sizes.billQty + '; color: #9E9EB0; margin-top: 1px; }';
        html += '.total-row { display: flex; justify-content: space-between; align-items: center; margin: 10px 0; }';
        html += '.total-label { font-weight: 900; font-size: ' + sizes.totalLabel + '; color: #1B0C3C; }';
        html += '.total-value { font-weight: 900; font-size: ' + sizes.totalValue + '; color: #0F9D58; }';
        html += '.qr-section { text-align: center; margin-top: 12px; }';
        html += '.centered { text-align: center; justify-content: center; }';
        html += '.qr-wrapper { position: relative; display: inline-block; margin: 8px 0; }';
        html += '.qr-code { width: ' + sizes.qrSize + '; height: ' + sizes.qrSize + '; border: 1px solid #ECEEF2; padding: 4px; background: white; }';
        html += '.qr-badge { position: absolute; top: 6px; right: 6px; background-color: #1B0C3C; color: white; font-size: ' + sizes.qrBadge + '; font-weight: 900; padding: 2px 4px; border-radius: 3px; letter-spacing: 0.3px; }';
        html += '.qr-desc { font-size: ' + sizes.qrDesc + '; color: #9E9EB0; margin-bottom: 2px; }';
        html += '.qr-id { font-size: ' + sizes.qrId + '; color: #BBBBCC; font-weight: bold; }';
        html += '.manual-prescription-box { text-align: left; background-color: #F8F9FF; border: 1px solid #E8E8F0; border-radius: 6px; padding: 8px; margin-top: 10px; }';
        html += '.manual-prescription-title { font-size: ' + sizes.manualTitle + '; font-weight: 900; color: #6F6A8A; letter-spacing: 0.3px; margin-bottom: 4px; }';
        html += '.manual-prescription-item { display: flex; align-items: center; font-size: ' + sizes.manualItem + '; color: #3D3D5C; margin-bottom: 2px; }';
        html += '.bullet { color: #9E9EB0; margin-right: 6px; font-weight: bold; }';
        html += '.footer { text-align: center; margin-top: 12px; font-size: ' + sizes.footer + '; }';
        html += '.footer-thankyou { color: #9E9EB0; }';
        html += '.footer-powered { font-weight: bold; color: #BBBBCC; margin-top: 2px; }';
        html += '@media print { body { margin: 0 !important; padding: 0 !important; } .invoice-container { page-break-inside: avoid !important; break-inside: avoid !important; } }';
        html += '</style></head><body>';
        
        html += '<div class="invoice-container">';
        html += '<div class="header">';
        html += logoHtml;
        html += '<h1 class="clinic-name">Praktik Mandiri</h1>';
        html += '<div class="doctor-name">' + data.doctorName + '</div>';
        html += '<div class="doctor-specialty">' + data.doctorSpecialty + '</div>';
        html += '</div>';
        html += '<div class="divider"></div>';
        html += '<div class="meta-section">';
        html += '<div class="meta-row"><div class="meta-label">No. Invoice</div><div class="meta-value">: ' + data.invoiceNo + '</div></div>';
        html += '<div class="meta-row"><div class="meta-label">Tanggal</div><div class="meta-value">: ' + data.date + '</div></div>';
        html += '<div class="meta-row"><div class="meta-label">Nama Pasien</div><div class="meta-value">: ' + data.patientName + '</div></div>';
        html += '<div class="meta-row"><div class="meta-label">NIK</div><div class="meta-value">: ' + data.patientNik + '</div></div>';
        html += '<div class="meta-row"><div class="meta-label">Jenis</div><div class="meta-value">: ' + data.patientType + '</div></div>';
        html += '</div>';
        html += '<div class="divider"></div>';
        html += '<div class="section-title">RINCIAN TAGIHAN</div>';
        html += '<div class="bill-item">';
        html += '<div class="bill-info"><div class="bill-name">Jasa Dokter / Konsultasi</div></div>';
        html += '<div class="bill-price-qty"><div class="bill-price">' + data.doctorPrice + '</div><div class="bill-qty">x1</div></div>';
        html += '</div>';
        
        data.medicines.forEach(function(m) {
          html += '<div class="bill-item">';
          html += '<div class="bill-info">';
          html += '<div class="bill-name">' + m.name + '</div>';
          if (m.isManual) {
            html += '<div class="bill-manual">RESEP MANUAL</div>';
          }
          html += '</div>';
          html += '<div class="bill-price-qty">';
          html += '<div class="bill-price' + (m.isManual ? ' manual' : '') + '">' + m.price + '</div>';
          html += '<div class="bill-qty">' + m.qty + '</div>';
          html += '</div>';
          html += '</div>';
        });
        
        html += '<div class="divider"></div>';
        html += '<div class="total-row">';
        html += '<div class="total-label">TOTAL</div>';
        html += '<div class="total-value">' + data.totalPrice + '</div>';
        html += '</div>';
        
        if (data.hasEResep) {
          html += '<div class="divider"></div>';
          html += '<div class="qr-section">';
          html += '<div class="section-title centered">E-RESEP / ELECTRONIC PRESCRIPTION</div>';
          html += '<div class="qr-wrapper">';
          html += '<img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=' + encodeURIComponent(data.qrData) + '" class="qr-code" />';
          html += '<div class="qr-badge">APOTEK</div>';
          html += '</div>';
          html += '<div class="qr-desc">Scan dengan aplikasi Apotek untuk membuka resep</div>';
          html += '<div class="qr-id">ID: ' + data.electronicPrescriptionId + '</div>';
          
          var hasManualPrescription = data.medicines.some(function(m) { return m.isManual; });
          if (hasManualPrescription) {
             html += '<div class="manual-prescription-box">';
             html += '<div class="manual-prescription-title">DAFTAR RESEP MANUAL</div>';
             data.medicines.forEach(function(m) {
               if (m.isManual) {
                 html += '<div class="manual-prescription-item"><span class="bullet">•</span><span class="manual-item-text">' + m.name + ' ' + m.qty + '</span></div>';
               }
             });
             html += '</div>';
          }
          html += '</div>';
        }
        
        html += '<div class="divider"></div>';
        html += '<div class="footer">';
        html += '<div class="footer-thankyou">Terima kasih atas kepercayaan Anda.</div>';
        html += '<div class="footer-powered">Powered by MAPOTECH</div>';
        html += '</div>';
        html += '</div></body></html>';
        
        var doc = iframe.contentWindow.document;
        doc.open();
        doc.write(html);
        doc.close();

        iframe.onload = function() {
          setTimeout(function() {
            try {
              var iframeDoc = iframe.contentWindow.document;
              var pageStyle = pageSize;
              var effectiveMargin = margin;
              if (isThermalSize) {
                effectiveMargin = '0mm';
                var contentHeightPx = iframeDoc.body.scrollHeight;
                var contentHeightMm = Math.ceil(contentHeightPx * 0.2646) + 4;
                var widthPart = pageSize.split(' ')[0];
                pageStyle = widthPart + ' ' + contentHeightMm + 'mm';
              }
              var styleTag = iframeDoc.createElement('style');
              styleTag.textContent = '@page { size: ' + pageStyle + '; margin: ' + effectiveMargin + '; } @media print { @page { margin: ' + effectiveMargin + ' !important; } html, body { margin: 0 !important; padding: 0 !important; } .invoice-container { page-break-inside: avoid !important; break-inside: avoid !important; } }';
              iframeDoc.head.appendChild(styleTag);
              iframe.contentWindow.print();
            } catch(e) {}
          }, 600);
        };
      };
      ''',
    ]);
    js.context.callMethod('__mapotech_print_invoice', [jsonData]);
  } catch (_) {}
}
