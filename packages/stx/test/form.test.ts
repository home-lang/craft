import { describe, expect, test } from 'bun:test'
import { defineForm, v } from '../src/form'

describe('defineForm', () => {
  test('create form with fields', () => {
    const form = defineForm({
      name: v.required,
      email: v.required.email,
    })

    expect(form.values.name()).toBe('')
    expect(form.values.email()).toBe('')
  })

  test('required validation', () => {
    const form = defineForm({
      name: v.required,
    })

    // Empty = error
    expect(form.errors.name()).toBe('This field is required')

    // Filled = no error
    form.values.name.set('John')
    expect(form.errors.name()).toBeNull()
  })

  test('email validation', () => {
    const form = defineForm({
      email: v.required.email,
    })

    form.values.email.set('invalid')
    expect(form.errors.email()).toBe('Invalid email address')

    form.values.email.set('test@example.com')
    expect(form.errors.email()).toBeNull()
  })

  test('min/max validation', () => {
    const form = defineForm({
      password: v.required.min(8).max(100),
    })

    form.values.password.set('short')
    expect(form.errors.password()).toBe('Must be at least 8')

    form.values.password.set('longenoughpassword')
    expect(form.errors.password()).toBeNull()
  })

  test('number validation', () => {
    const form = defineForm({
      age: v.number.positive,
    })

    form.values.age.set('abc')
    expect(form.errors.age()).toBe('Must be a number')

    form.values.age.set('-5')
    expect(form.errors.age()).toBe('Must be positive')

    form.values.age.set('25')
    expect(form.errors.age()).toBeNull()
  })

  test('hasErrors derived', () => {
    const form = defineForm({
      name: v.required,
    })

    expect(form.hasErrors()).toBe(true)

    form.values.name.set('John')
    expect(form.hasErrors()).toBe(false)
  })

  test('reset clears all values', () => {
    const form = defineForm({
      name: v.required,
      email: v.required,
    })

    form.values.name.set('John')
    form.values.email.set('john@test.com')
    form.reset()

    expect(form.values.name()).toBe('')
    expect(form.values.email()).toBe('')
  })

  test('custom validator', () => {
    const form = defineForm({
      code: v.custom((val) => {
        return String(val).startsWith('STX') ? null : 'Must start with STX'
      }),
    })

    form.values.code.set('ABC')
    expect(form.errors.code()).toBe('Must start with STX')

    form.values.code.set('STX123')
    expect(form.errors.code()).toBeNull()
  })

  test('between validation', () => {
    const form = defineForm({
      rating: v.number.between(1, 5),
    })

    form.values.rating.set('7')
    expect(form.errors.rating()).toBe('Must be between 1 and 5')

    form.values.rating.set('3')
    expect(form.errors.rating()).toBeNull()
  })
})
