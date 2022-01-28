import { createWorker, Worker } from 'tesseract.js'

customElements.define('pos-ocr',
  class extends HTMLElement {

    //  Private fields
    #document: string = ''

    constructor() {
      super()
    }

    get document() {
      return this.#document
    }

    set document(value: string) {

      this.#document = value
      console.log('Setting documents value to ', this.#document)

      if (this.#document == '') { return }  //  Don't do anything further if there is no input

      //  Now, recognise the text
      const worker: Worker = createWorker({ logger: (m) => { console.log(m) } });

      (async () => {
        await worker.load()
        await worker.loadLanguage('eng')
        await worker.initialize('eng')
        const { data: { text } } = await worker.recognize(this.#document)
        this.dispatchEvent(new CustomEvent('recognisedText', { detail: { recognisedText: text } }))
        await worker.terminate()
      })()

    }
  }
)