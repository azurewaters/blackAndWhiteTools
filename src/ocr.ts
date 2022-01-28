import { saveAs } from "file-saver"
import { createScheduler, createWorker, Scheduler, Worker } from "tesseract.js"
import { OCRListingFile, OCRRecognitionResult } from "./Types"

async function recogniseTextInTheseFiles(ocrListingFiles: OCRListingFile[]): Promise<OCRRecognitionResult[]> {
  //  This is where we take a file, and depending 
  //  on whether or not it is an image or PDF
  //  it is sent to be recognised or decomposed into images

  //  Create the workers that will do the recognition
  let numberOfWorkers = Math.min(5, ocrListingFiles.length)   //  At max, have 5 workers
  const scheduler: Scheduler = createScheduler()
  for (let index = 0; index < numberOfWorkers; index++) {
    const worker: Worker = createWorker({
      corePath: '../node_modules/tesseract.js-core/tesseract-core.wasm.js',
      workerPath: '../node_modules/tesseract.js/dist/worker.min.js',
      langPath: '../assets',
      logger: m => console.log(m)
    })
    await worker.load()
    await worker.loadLanguage('eng')
    await worker.initialize('eng')

    scheduler.addWorker(worker)
  }

  //  Process the images
  const results = await Promise.all(
    ocrListingFiles.map(async (ocrListingFile: OCRListingFile): Promise<OCRRecognitionResult> => {
      if (['image/png', 'image/jpeg'].includes(ocrListingFile.file.type)) {

        let resultOfRecognition = await scheduler.addJob('recognize', ocrListingFile.file)

        let result: OCRRecognitionResult = {
          ocrListingId: ocrListingFile.ocrListingId,
          text: ''
        }
        if ('text' in resultOfRecognition.data) { result.text = resultOfRecognition.data.text }

        let pdf = await scheduler.addJob('getPDF', resultOfRecognition.jobId)
        saveAs(new Blob([new Uint8Array(pdf.data)], { type: 'application/pdf' }), 'todo-namethisproperly.pdf')

        return result

      }
    })
  )

  //  Clean up
  await scheduler.terminate()

  return results
}

export { recogniseTextInTheseFiles }