import { ethers } from "hardhat";
import { AbiCoder } from "ethers";
import { stringifyData } from "@vechain/sdk-errors";
import { Wallet } from "@vechain/vechain-kit";
import { Keccak256 } from "@vechain/sdk-core";
import { VeChainProvider, type VeChainSigner } from "@vechain/sdk-network";

async function main(): Promise<void> {
  const signer = (await ethers.getSigners())[0];

  const vechainHelloWorldFactory = await ethers.getContractFactory(
    "Cycle2earn",
    signer
  );

  const txResponse = await vechainHelloWorldFactory.deploy(
    "0x5F8f86B8D0Fa93cdaE20936d150175dF0205fB38",
    "0x8cb2b80576d5605f40243c80a80f70191584c0c3c901d54cbfba9df2d4e5c743",
    "0xcc1190e025b6b94e8827e9a4b51b61ee13c2ba93"
  );

  await txResponse.waitForDeployment();

  console.log(
    "Contract deployment with the following transaction:",
    stringifyData(txResponse)
  );

  //   const cycle2earn = vechainHelloWorldFactory.attach(txResponse.target);

  //   const wallet = new Wallet(signer.a);

  //   const tx = await wallet.sendTransaction({
  //     to: cycle2earn.target,
  //   });
  // abi.encodePacked(user, amount)
  //   const message = Keccak256.of(
  //     "0xcc1190e025b6b94e8827e9a4b51b61ee13c2ba93"
  //   );

  //   const message = ethers.solidityPacked(
  //     ["address", "uint256"],
  //     [signer.address, 100]
  //   );

  //   // Hash it the same way Solidity does
  //   const hash = ethers.hashMessage(message);
  //   console.log(hash);

  //   // Get the VeChain provider and signer for proper message signing
  //   const hre = await import("hardhat");
  //   const vechainProvider = hre.default.VeChainProvider;

  //   if (!vechainProvider) {
  //     throw new Error(
  //       "VeChain provider not available. Make sure you're using a VeChain network."
  //     );
  //   }

  //   const vechainSigner = (await vechainProvider.getSigner(
  //     signer.address
  //   )) as VeChainSigner;

  //   // Use VeChain SDK's native signing method
  //   const signature = await vechainSigner.signMessage(hash);
  //   console.log("signature", signature);

  const setReward = await txResponse.addRewardAlt(signer.address, 100);

  const receipt = await setReward.wait();
  console.log(receipt);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
