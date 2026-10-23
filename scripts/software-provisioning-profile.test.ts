import { expect, test } from 'bun:test'
import { softwareProvisioningCpus } from './software-provisioning-profile'

test('the release acceptance CPU profile cannot be overridden by a diagnostic input', () => {
  expect(softwareProvisioningCpus(false, undefined)).toBe(2)
  expect(softwareProvisioningCpus(false, '1')).toBe(2)
})

test('diagnostics select an explicit bounded CPU count and retain the control by default', () => {
  expect(softwareProvisioningCpus(true, undefined)).toBe(2)
  for (const cpu of [1, 2, 3, 4]) expect(softwareProvisioningCpus(true, String(cpu))).toBe(cpu)
})

test('invalid diagnostic CPU counts fail before starting native tools', () => {
  for (const cpu of ['', '0', '5', '-1', '1.5', 'NaN', 'Infinity', ' 1', '1e0'])
    expect(() => softwareProvisioningCpus(true, cpu)).toThrow('diagnostic virtual CPUs')
})
