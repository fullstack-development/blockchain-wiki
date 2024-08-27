const { buildModule } = require('@nomicfoundation/hardhat-ignition/modules');

module.exports = buildModule('OriginTokenModule', (m) => {
    const originToken = m.contract('OriginToken');

    return { originToken };
});
