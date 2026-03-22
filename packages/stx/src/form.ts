/* eslint-disable pickier/no-unused-vars */
/**
 * STX Form Validation
 *
 * Provides defineForm() with chainable validators for reactive form handling.
 */

import { state, derived } from './runtime'
import type { State, Derived } from './runtime'

// ============================================================================
// Validator chain
// ============================================================================

type ValidatorFn = (value: unknown) => string | null

interface ValidatorChain {
  required: ValidatorChain
  email: ValidatorChain
  url: ValidatorChain
  min: (n: number) => ValidatorChain
  max: (n: number) => ValidatorChain
  pattern: (regex: RegExp, message?: string) => ValidatorChain
  number: ValidatorChain
  integer: ValidatorChain
  positive: ValidatorChain
  between: (min: number, max: number) => ValidatorChain
  alphanumeric: ValidatorChain
  custom: (fn: (value: unknown) => string | null) => ValidatorChain
  _validators: ValidatorFn[]
}

function createChain(validators: ValidatorFn[] = []): ValidatorChain {
  const chain: ValidatorChain = {
    _validators: validators,

    get required() {
      return createChain([...validators, (v) => {
        if (v === null || v === undefined || v === '') return 'This field is required'
        return null
      }])
    },

    get email() {
      return createChain([...validators, (v) => {
        if (!v) return null
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(v)) ? null : 'Invalid email address'
      }])
    },

    get url() {
      return createChain([...validators, (v) => {
        if (!v) return null
        try { new URL(String(v)); return null }
        catch { return 'Invalid URL' }
      }])
    },

    min(n: number) {
      return createChain([...validators, (v) => {
        if (!v) return null
        const len = typeof v === 'string' ? v.length : Number(v)
        return len >= n ? null : `Must be at least ${n}`
      }])
    },

    max(n: number) {
      return createChain([...validators, (v) => {
        if (!v) return null
        const len = typeof v === 'string' ? v.length : Number(v)
        return len <= n ? null : `Must be at most ${n}`
      }])
    },

    pattern(regex: RegExp, message?: string) {
      return createChain([...validators, (v) => {
        if (!v) return null
        return regex.test(String(v)) ? null : (message ?? 'Invalid format')
      }])
    },

    get number() {
      return createChain([...validators, (v) => {
        if (!v) return null
        return Number.isNaN(Number(v)) ? 'Must be a number' : null
      }])
    },

    get integer() {
      return createChain([...validators, (v) => {
        if (!v) return null
        return Number.isInteger(Number(v)) ? null : 'Must be an integer'
      }])
    },

    get positive() {
      return createChain([...validators, (v) => {
        if (!v) return null
        return Number(v) > 0 ? null : 'Must be positive'
      }])
    },

    between(min: number, max: number) {
      return createChain([...validators, (v) => {
        if (!v) return null
        const n = Number(v)
        return n >= min && n <= max ? null : `Must be between ${min} and ${max}`
      }])
    },

    get alphanumeric() {
      return createChain([...validators, (v) => {
        if (!v) return null
        return /^[a-zA-Z0-9]+$/.test(String(v)) ? null : 'Must be alphanumeric'
      }])
    },

    custom(fn: (value: unknown) => string | null) {
      return createChain([...validators, fn])
    },
  }

  return chain
}

/** Validator chain builder */
export const v = createChain()

// ============================================================================
// Form definition
// ============================================================================

type FormFields = Record<string, ValidatorChain>
type FormValues<F extends FormFields> = { [K in keyof F]: State<string> }
type FormErrors<F extends FormFields> = { [K in keyof F]: Derived<string | null> }

export interface FormInstance<F extends FormFields> {
  values: FormValues<F>
  errors: FormErrors<F>
  hasErrors: Derived<boolean>
  validate: () => boolean
  reset: () => void
  handleSubmit: (onSubmit: (values: Record<keyof F, string>) => void | Promise<void>) => (e?: Event) => void
}

/**
 * Define a reactive form with validation.
 *
 * @example
 * const form = defineForm({
 *   email: v.required.email,
 *   password: v.required.min(8),
 *   age: v.number.positive.between(18, 120),
 * })
 *
 * // In template:
 * // <input @model="form.values.email" />
 * // <span @show="form.errors.email()">{{ form.errors.email() }}</span>
 *
 * form.handleSubmit((values) => {
 *   console.log(values) // { email: '...', password: '...', age: '...' }
 * })
 */
export function defineForm<F extends FormFields>(fields: F): FormInstance<F> {
  const values: Record<string, State<string>> = {}
  const errors: Record<string, Derived<string | null>> = {}

  for (const [key, chain] of Object.entries(fields)) {
    values[key] = state('')
    const fieldState = values[key]
    const validators = chain._validators

    errors[key] = derived(() => {
      const val = fieldState()
      for (const validator of validators) {
        const error = validator(val)
        if (error) return error
      }
      return null
    })
  }

  const hasErrors = derived(() => {
    return Object.values(errors).some(err => err() !== null)
  })

  const validate = (): boolean => {
    // Touch all fields to trigger validation
    for (const fieldState of Object.values(values)) {
      fieldState() // trigger read
    }
    return !hasErrors()
  }

  const reset = () => {
    for (const fieldState of Object.values(values)) {
      fieldState.set('')
    }
  }

  const handleSubmit = (onSubmit: (values: Record<keyof F, string>) => void | Promise<void>) => {
    return (e?: Event) => {
      e?.preventDefault?.()
      if (validate()) {
        const result: Record<string, string> = {}
        for (const [key, fieldState] of Object.entries(values)) {
          result[key] = fieldState()
        }
        onSubmit(result as Record<keyof F, string>)
      }
    }
  }

  return {
    values: values as FormValues<F>,
    errors: errors as FormErrors<F>,
    hasErrors,
    validate,
    reset,
    handleSubmit,
  }
}
