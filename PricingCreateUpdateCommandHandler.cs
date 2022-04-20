using AutoMapper;
using MediatR;
using StoredProcedureEFCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Text;
using SceletonAPI.Application.UseCases.MasterData.Command.PricingCreateUpdate;
using SceletonAPI.Application.Interfaces;
using SceletonAPI.Domain.Entities;

namespace SceletonAPI.Application.UseCases.MasterData.Command.PricingCreateUpdate
{
    public class PricingCreateUpdateCommandHandler : IRequestHandler<PricingCreateUpdateCommand, PricingCreateUpdateDto>
    {
        private readonly IVTSDBContext _context;
        private readonly IMapper _mapper;

        public PricingCreateUpdateCommandHandler(IVTSDBContext context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        public async Task<PricingCreateUpdateDto> Handle(PricingCreateUpdateCommand request, CancellationToken cancellationToken)
        {
            var response = new PricingCreateUpdateDto();
			List<string> destinationCode = new();
			List<string> vendorCode = new();
			List<string> modelName = new();
			List<string> deliveryMode = new();
			int count = new();
			List<MasterDataPricing> spinsertPricing = null;
			
            foreach(var i in request.Data)
            {
                _context.loadStoredProcedureBuilder("SP_InsertUpdate_PricingMasterData")
                    .AddParam("Region", i.Region)
                    .AddParam("DestinationCode", i.DestinationCode)
                    .AddParam("VendorCode", i.VendorCode)
                    .AddParam("ModelName", i.CarModel)
                    .AddParam("Price", i.Price)
                    .AddParam("DeliveryMode", i.DeliveryMode)
                    .AddParam("UpdatedBy", i.UpdatedBy)
                    .Exec(r => spinsertPricing = r.ToList<MasterDataPricing>());
			
				// if something wrong happening when inserting or updating the database, the sql will return a value
				if (spinsertPricing.Any()) 
				{
					// each wrong value will be added to corresponding List<string>
					// adding the `Distinct()` method will be filtering the value to be only showed once, thus avoiding duplication
					foreach (var result in spinsertPricing) 
					{
						if (result.DestinationCode!= null){
							destinationCode.Add(result.DestinationCode);
							destinationCode = destinationCode.Distinct().ToList();
						}
						if (result.VendorCode!= null){
							vendorCode.Add(result.VendorCode);
							vendorCode = vendorCode.Distinct().ToList();
						}
						if (result.ModelName!= null){
							modelName.Add(result.ModelName);
							modelName = modelName.Distinct().ToList();
						}
						if (result.DeliveryMode!= null){
							deliveryMode.Add(result.DeliveryMode);
							deliveryMode = deliveryMode.Distinct().ToList();
						}
					}	
				// each failed insert or update will increment the `count` variable to count failed data insertion
				count++;
				}
			}
			if (destinationCode.Any() || vendorCode.Any() || modelName.Any() || deliveryMode.Any())
			{
				string message = " data gagal terunggah karena ";
				if (destinationCode.Any()){
					message = message + "kode destinasi " + (string.Join( ", ", destinationCode)) + "; ";
				}
				if (vendorCode.Any()){
					message = message + "kode vendor " + (string.Join( ", ", vendorCode)) + "; ";
				}
				if (modelName.Any()){
					message = message + "model mobil " + (string.Join( ", ", modelName)) + "; ";
				}
				if (deliveryMode.Any()){
					message = message + "mode pengiriman " + (string.Join( ", ", deliveryMode)) + "; ";
				}
				response.Success = false;
				response.Message = count.ToString() + message + "tidak ditemukan di dalam database kami.";

				return response;
			}
            response.Success = true;
            response.Message = "Pricing berhasil dibuat atau diupdate";

            return response;			
        }
    }
}
