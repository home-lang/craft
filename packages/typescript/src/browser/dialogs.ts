export interface BrowserDialogOptions {
  title?: string
  message?: string
  confirmLabel?: string
  cancelLabel?: string
  buttons?: Array<{ id: string, title?: string, label?: string, style?: string }>
  actions?: Array<{ id: string, title?: string, label?: string, style?: string }>
}

/** A user-owned browser dialog, with keyboard focus and cancellation, not a timed prompt. */
export function showBrowserDialog(kind: string, options: BrowserDialogOptions, signal: AbortSignal): Promise<string | boolean | undefined> {
  return new Promise((resolve, reject) => {
    if (signal.aborted) { reject(signal.reason); return }
    const previous = document.activeElement as HTMLElement | null
    const dialog = document.createElement('dialog')
    dialog.style.cssText = 'font:16px system-ui;max-width:min(400px,90vw);padding:24px;border:1px solid #8885;border-radius:16px;color:CanvasText;background:Canvas;box-shadow:0 16px 64px #0004'
    dialog.setAttribute('aria-modal', 'true')
    const title = document.createElement('h2'); title.id = `craft-dialog-${crypto.randomUUID()}`; title.textContent = String(options.title ?? ''); title.style.cssText = 'font-size:20px;margin:0 0 12px'; dialog.append(title); dialog.setAttribute('aria-labelledby', title.id)
    if (options.message) { const message = document.createElement('p'); message.textContent = options.message; dialog.append(message) }
    const finish = (answer: string | boolean | undefined): void => { signal.removeEventListener('abort', abort); dialog.close(); dialog.remove(); previous?.focus(); resolve(answer) }
    const abort = (): void => { dialog.close(); dialog.remove(); previous?.focus(); reject(signal.reason ?? new DOMException('Aborted', 'AbortError')) }
    signal.addEventListener('abort', abort, { once: true })
    const actions = options.buttons ?? options.actions ?? []
    const cancelAction = actions.find(item => item.style === 'cancel')
    const buttons = kind === 'actionSheet' ? actions.filter(item => item.style !== 'cancel') : [{ id: 'confirm', title: options.confirmLabel ?? 'OK' }]
    const controls = document.createElement('div'); controls.style.cssText = 'display:flex;flex-direction:column;gap:8px;margin-top:20px'
    for (const item of buttons) {
      const button = document.createElement('button'); button.type = 'button'; button.textContent = String(item.title ?? item.label ?? item.id); button.style.cssText = `font:inherit;min-height:44px;border:1px solid #8885;border-radius:8px;background:transparent;color:${item.style === 'destructive' ? '#e11d48' : 'inherit'}`; button.onclick = () => finish(kind === 'actionSheet' ? item.id : kind === 'confirm' ? true : undefined); controls.append(button)
    }
    if (kind !== 'alert') { const cancel = document.createElement('button'); cancel.type = 'button'; cancel.textContent = options.cancelLabel ?? cancelAction?.title ?? cancelAction?.label ?? 'Cancel'; cancel.style.cssText = 'font:inherit;min-height:44px;border:0;background:none;color:inherit'; cancel.onclick = () => finish(kind === 'confirm' ? false : undefined); controls.append(cancel) }
    dialog.addEventListener('cancel', (event) => { event.preventDefault(); finish(kind === 'confirm' ? false : undefined) })
    dialog.append(controls); document.body.append(dialog); dialog.showModal()
  })
}
