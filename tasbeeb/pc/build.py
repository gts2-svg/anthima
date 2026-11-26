import base64, pathlib
NM='/home/claude/t/node_modules/'
src=pathlib.Path('src.html').read_text(encoding='utf-8')
r=lambda p: pathlib.Path(NM+p).read_text(encoding='utf-8')
ara=base64.b64encode(pathlib.Path(NM+'@tesseract.js-data/ara/4.0.0_best_int/ara.traineddata.gz').read_bytes()).decode()
assets=f'''
<script type="text/plain" id="srcTessCore">{r('tesseract.js-core/tesseract-core-simd-lstm.wasm.js')}</script>
<script type="text/plain" id="srcTessWorker">{r('tesseract.js/dist/worker.min.js')}</script>
<script type="text/plain" id="srcPdfWorker">{r('pdfjs-dist/build/pdf.worker.min.js')}</script>
<script type="text/plain" id="araData">{ara}</script>
<script>{r('tesseract.js/dist/tesseract.min.js')}</script>
<script>{r('pdfjs-dist/build/pdf.min.js')}</script>
<script>
{pathlib.Path('att.js').read_text(encoding='utf-8')}
</script>
'''
out=src.replace('</body>', assets+'</body>',1)
pathlib.Path('مولد_التسبيب.html').write_text(out,encoding='utf-8')
print(len(out.encode())/1e6,'MB')
