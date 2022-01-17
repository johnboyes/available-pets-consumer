# Consumer-driven contracts in GitLab

## Proposal on how to define the relationship between the consumers, contracts and providers

- Group the contract GitLab projects together with the consumer project in a GitLab [group](https://docs.gitlab.com/ee/user/group/) or [subgroup](https://docs.gitlab.com/ee/user/group/subgroups/) (as they are *consumer-driven* contracts, so their natural grouping is to be located with the consumer)
- Follow [12 factor config principles](https://12factor.net/config) by having GitLab environment-specific variables for a given provider's endpoints
  - for example, let's say we have a consumer GitLab project called `petstore-web` and a provider project called `petstore-service`
  - let's say also that we have many environments where we want to deploy these applications, and suppose these environments include:
    - an ephemeral environment per feature branch
    - `trunk`
    - `uat`
    - `production`
  - the consumer should have environment-specific config e.g. a [GitLab CI CD variable](https://docs.gitlab.com/ee/ci/variables/index.html) that refers to the provider's endpoint using a standard naming convention, e.g. `<provider-namespace>-<provider-project-name>-provider-url` (so `thenamespace-petstore-service-provider-url` for our above example) would be one possible naming convention.  [Read more on GitLab namespaces](https://docs.gitlab.com/ee/user/group/#namespaces).
  - example `thenamespace-petstore-service-provider-url` values for the different environments:
    - `my-feature-branch`: `https://my-feature-branch.petstore-service-mock.thenamespace.example.com`
    - `trunk`: `https://trunk.petstore-service-mock.thenamespace.example.com`
    - `uat`: `https://uat.petstore-service.thenamespace.example.com`
    - `production`: `https://petstore-service.thenamespace.example.com`
  - the value for the feature branch environment url will of course need to be dynamically set, based on the feature branch name (or merge request number).  We can set the value on the fly using the [GitLab Variables API](https://docs.gitlab.com/ee/api/project_level_variables.html#update-variable).
  - let's say that we are using [Prism](https://meta.stoplight.io/docs/prism/) to setup the mocks on the feature branch and `trunk` environments
    - in order to setup the Prism mocks we need to know the name of the corresponding contract GitLab project.  So we need to have a standard naming convention for all contract GitLab projects.  This could be something like `<provider-project-name>-contract`, e.g. `petstore-service-contract`.
     - this allows us to dynamically setup the Prism mocks for all of the providers for our consumer, by:
       - iterating over all GitLab CI CD provider variables (i.e. all the variables that end with `provider-url`, in our notional naming convention), and for each provider variable:
       1. infer the contract GitLab project name by parsing the provider variable name
       2. start a Prism mock on a container, and configure it to be accessible on the correct URL as per our naming convention (e.g. `https://my-feature-branch.petstore-service-mock.thenamespace.example.com`)
       3. use the [GitLab Variables API](https://docs.gitlab.com/ee/api/project_level_variables.html#update-variable) to dynamically set the CI CD variable value for the dynamic feature branch environment, e.g. set `thenamespace-petstore-service-provider-url` to be `https://my-feature-branch.petstore-service-mock.thenamespace.example.com`, [scoped to the dynamic feature branch environment in GitLab](https://docs.gitlab.com/ee/ci/environments/#create-a-dynamic-environment).

- This approach also allows us to dynamically infer all of the consumer to provider relationships for the entire GitLab organisation, simply by writing a script that uses the GitLab API to iterate over all the GitLab projects in the organisation, and then iterate over all the CI CD variables for each project that end with `provider-url` in our example.  It would be straightforward to expose this in whatever formats we need (e.g. a website showing the relationships in a graph, or in a service, etc etc).
